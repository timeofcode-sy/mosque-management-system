<?php

namespace Tests\Feature\Notifications;

use App\Actions\CompleteAttendanceSession;
use App\Actions\ReviewAbsenceExcuse;
use App\Contracts\PushNotifier;
use App\Enums\AttendanceStatus;
use App\Enums\ExcuseStatus;
use App\Enums\GuardianRelation;
use App\Models\AbsenceExcuse;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\Device;
use App\Models\Guardian;
use App\Models\GuardianStudent;
use App\Models\Student;
use App\Models\User;
use App\Notifications\NullPushNotifier;
use App\Notifications\PushMessage;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * قناةٌ مزيّفة تسجّل ما أُرسل — النظيرُ الاختباري لـ`PushNotifier`.
 *
 * ولا `Notification::fake()`: هذه ليست قناةَ Laravel بل واجهةَ المشروع نفسِه،
 * وتزييفُها بربطٍ في الحاوية يختبر **العقد** لا تنفيذَ إطارٍ ثالث.
 */
class RecordingPushNotifier implements PushNotifier
{
    /** @var array<int, array{tokens: array<int, string>, message: PushMessage}> */
    public array $sent = [];

    public function send(array $tokens, PushMessage $message): int
    {
        $this->sent[] = ['tokens' => $tokens, 'message' => $message];

        return count($tokens);
    }

    /** @return array<int, string> */
    public function titles(): array
    {
        return array_map(fn (array $row) => $row['message']->title, $this->sent);
    }

    /** @return array<int, string> */
    public function allTokens(): array
    {
        return array_merge(...array_map(fn (array $row) => $row['tokens'], $this->sent)) ?: [];
    }
}

/**
 * عقدُ الإشعار الفوري — م.7.4.
 *
 * ما يحرسه: **متى** يُشعَر (عند استقرار الكشف لا عند كل ضغطة)، و**مَن** يُشعَر
 * (أجهزةُ أولياء أمر هذا الطالب في تطبيقهم وحده)، و**ألّا يسقط الفعلُ** حين لا
 * تكون هناك قناةٌ أصلاً.
 */
class GuardianPushTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private RecordingPushNotifier $push;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();

        $this->push = new RecordingPushNotifier;
        $this->app->instance(PushNotifier::class, $this->push);
    }

    /**
     * 🔑 القرارُ الحاكم: الإشعارُ عند **الإغلاق** لا عند كل كتابة.
     */
    public function test_no_notification_is_sent_while_the_roll_is_still_being_taken(): void
    {
        [$student] = $this->studentWithGuardianDevice();
        $this->sessionWith($student, AttendanceStatus::Absent);

        // الجلسةُ مسودّةٌ بعد، والحالةُ قابلةٌ للتبدّل — فلا إعلان.
        $this->assertSame([], $this->push->sent);
    }

    public function test_closing_the_session_tells_the_guardians_of_the_absent(): void
    {
        [$student, $token] = $this->studentWithGuardianDevice();
        $session = $this->sessionWith($student, AttendanceStatus::Absent);

        app(CompleteAttendanceSession::class)->handle($session, $this->admin);

        $this->assertSame(['تسجيل غياب'], $this->push->titles());
        $this->assertSame([$token], $this->push->allTokens());

        $message = $this->push->sent[0]['message'];
        $this->assertStringContainsString($student->full_name, $message->body);
        $this->assertSame('absence', $message->data['type']);
        $this->assertSame($student->uuid, $message->data['student_uuid']);
    }

    public function test_only_the_absent_are_announced(): void
    {
        [$present] = $this->studentWithGuardianDevice('tok-present');
        [$absent] = $this->studentWithGuardianDevice('tok-absent');

        $session = $this->sessionWith($present, AttendanceStatus::Present);
        Attendance::factory()->create([
            'attendance_session_id' => $session->id,
            'student_id' => $absent->id,
            'status' => AttendanceStatus::Absent,
        ]);

        app(CompleteAttendanceSession::class)->handle($session, $this->admin);

        $this->assertSame(['tok-absent'], $this->push->allTokens());
    }

    /**
     * إكمالُ المكتملة يقع في التصحيح الرجعي — والإشعارُ أثرُ **انتقالٍ** لا حالة.
     */
    public function test_completing_an_already_completed_session_does_not_announce_again(): void
    {
        [$student] = $this->studentWithGuardianDevice();
        $session = $this->sessionWith($student, AttendanceStatus::Absent);

        app(CompleteAttendanceSession::class)->handle($session, $this->admin);
        app(CompleteAttendanceSession::class)->handle($session->refresh(), $this->admin);

        $this->assertCount(1, $this->push->sent);
    }

    /**
     * الجهازُ يُميَّز بتطبيقه: لوليّ الأمر أن يكون أستاذاً بنفس الحساب، ورسالةٌ
     * عن ابنه لا مكانَ لها في تطبيق الأستاذ.
     */
    public function test_only_devices_of_the_guardian_app_are_targeted(): void
    {
        [$student, $token, $guardianUser] = $this->studentWithGuardianDevice();

        Device::create([
            'user_id' => $guardianUser->id,
            'app' => 'teacher',
            'fcm_token' => 'tok-teacher-surface',
            'platform' => 'android',
        ]);

        $session = $this->sessionWith($student, AttendanceStatus::Absent);
        app(CompleteAttendanceSession::class)->handle($session, $this->admin);

        $this->assertSame([$token], $this->push->allTokens());
    }

    public function test_a_student_with_no_guardian_device_is_simply_not_announced(): void
    {
        $orphan = Student::factory()->create(['institute_id' => $this->institute->id]);
        $session = $this->sessionWith($orphan, AttendanceStatus::Absent);

        app(CompleteAttendanceSession::class)->handle($session, $this->admin);

        // أُرسلت رسالةٌ بلا أجهزة — والقناةُ تتلقّاها فارغةً ولا ترمي.
        $this->assertSame([], $this->push->allTokens());
    }

    /**
     * ✅ تكملةُ الدائرة: هو من قدّم الإذن، فهو من يُبلَّغ بالحكم.
     */
    public function test_reviewing_an_excuse_tells_the_guardian_the_verdict(): void
    {
        [$student, $token] = $this->studentWithGuardianDevice();
        $excuse = AbsenceExcuse::factory()->create(['student_id' => $student->id]);

        app(ReviewAbsenceExcuse::class)->handle($excuse, ExcuseStatus::Rejected, $this->admin, 'الدورة في أيامها الأخيرة.');

        $this->assertSame(['رُفض إذن الغياب'], $this->push->titles());
        $this->assertSame([$token], $this->push->allTokens());
        $this->assertSame('0', $this->push->sent[0]['message']->data['approved']);
    }

    public function test_an_approved_excuse_announces_the_acceptance(): void
    {
        [$student] = $this->studentWithGuardianDevice();
        $excuse = AbsenceExcuse::factory()->create(['student_id' => $student->id]);

        app(ReviewAbsenceExcuse::class)->handle($excuse, ExcuseStatus::Approved, $this->admin);

        $this->assertSame(['قُبل إذن الغياب'], $this->push->titles());
        $this->assertSame('1', $this->push->sent[0]['message']->data['approved']);
    }

    /**
     * الحالةُ الابتدائية ليست بتّاً — ولو أُشعر عنها لَوصل «تحديثٌ» بلا معنى.
     */
    public function test_leaving_an_excuse_pending_announces_nothing(): void
    {
        [$student] = $this->studentWithGuardianDevice();
        $excuse = AbsenceExcuse::factory()->create(['student_id' => $student->id]);

        app(ReviewAbsenceExcuse::class)->handle($excuse, ExcuseStatus::Pending, $this->admin);

        $this->assertSame([], $this->push->sent);
    }

    /**
     * 🔑 **بلا حساب Firebase يعمل النظامُ كاملاً** — وهو ما يجعل م.7.4 مؤجَّلةً
     * بلا أن تحجب المرحلة السابعة.
     */
    public function test_without_any_channel_the_session_still_closes(): void
    {
        $this->app->instance(PushNotifier::class, new NullPushNotifier);

        [$student] = $this->studentWithGuardianDevice();
        $session = $this->sessionWith($student, AttendanceStatus::Absent);

        $closed = app(CompleteAttendanceSession::class)->handle($session, $this->admin);

        $this->assertSame('completed', $closed->status->value);
    }

    /**
     * @return array{0: Student, 1: string, 2: User}
     */
    private function studentWithGuardianDevice(string $token = 'tok-guardian'): array
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        $user = User::factory()->create();
        $guardian = Guardian::factory()->create([
            'institute_id' => $this->institute->id,
            'user_id' => $user->id,
        ]);

        GuardianStudent::create([
            'guardian_id' => $guardian->id,
            'student_id' => $student->id,
            'relation' => GuardianRelation::Father,
            'is_primary' => true,
            'can_view_reports' => true,
            'can_submit_excuses' => true,
        ]);

        Device::create([
            'user_id' => $user->id,
            'app' => 'guardian',
            'fcm_token' => $token,
            'platform' => 'android',
        ]);

        return [$student, $token, $user];
    }

    private function sessionWith(Student $student, AttendanceStatus $status): AttendanceSession
    {
        $courseCircle = $this->makeCourseCircle();

        $session = AttendanceSession::factory()->create([
            'course_circle_id' => $courseCircle->id,
        ]);

        Attendance::factory()->create([
            'attendance_session_id' => $session->id,
            'student_id' => $student->id,
            'status' => $status,
        ]);

        return $session;
    }
}
