<?php

namespace Tests\Feature\Livewire;

use App\Enums\AttendanceStatus;
use App\Enums\SessionStatus;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\Circle;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\Institute;
use App\Models\Shift;
use App\Models\Student;
use App\Models\SyncConflict;
use App\Models\User;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Livewire\Livewire;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * شاشة التعارضات بعد قرار 2026-09-07: خرجت من أدوات المبرمج إلى صاحب القرار في
 * المعهد، ومعها الحكم لا العرض وحده.
 *
 * ما يثبته هذا الملف ثلاثة أشياء لا يثبتها غيره:
 * حصرُ المعهد (وهو تسريبٌ محتمل لأن المعرّف يصل من المتصفّح)، وقلبُ الحكم بأنه
 * **كتابةٌ حقيقية** لا تعليمُ صفٍّ، وامتناعُه على الجلسة المقفلة.
 */
class SyncConflictPanelTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private Attendance $attendance;

    private SyncConflict $conflict;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();

        $courseCircle = $this->makeCourseCircle('حلقة أبي بن كعب');
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);

        $session = AttendanceSession::factory()->create([
            'course_circle_id' => $courseCircle->id,
            'session_date' => Carbon::today()->toDateString(),
            'status' => SessionStatus::Completed,
        ]);

        $this->attendance = Attendance::factory()->create([
            'attendance_session_id' => $session->id,
            'student_id' => $student->id,
            'status' => AttendanceStatus::Absent,
            'recorded_at' => Carbon::parse('2026-09-07 09:30:00'),
        ]);

        $this->conflict = SyncConflict::create([
            'institute_id' => $this->institute->id,
            'table_name' => 'attendances',
            'row_uuid' => $this->attendance->uuid,
            'server_payload' => $this->attendance->toArray(),
            'client_payload' => ['status' => AttendanceStatus::Present->value, 'recorded_at' => '2026-09-07 09:00:00'],
            'resolution' => 'server_wins',
        ]);
    }

    public function test_a_supervisor_sees_the_conflicts_of_their_own_institute(): void
    {
        $supervisor = User::factory()->create();
        $this->assignRole($supervisor, 'supervisor');
        $this->actingAs($supervisor)->withSession(['institute_id' => $this->institute->id]);

        /** الجدول يقصّ المعرّف إلى 13 محرفاً، فالمقارنة على المقصوص لا على الكامل */
        Livewire::test('pages::system.sync-conflicts')->assertSee(Str::limit($this->attendance->uuid, 13));
    }

    /**
     * الحالة التي يمنعها الحصر: معهدٌ آخر، ومعرّفٌ صالح — الحارس صلاحيةٌ لا نطاق،
     * فلولا الحصر في الاستعلام لَرآه ولقلَبه.
     */
    public function test_a_conflict_from_another_institute_is_neither_listed_nor_actionable(): void
    {
        $other = $this->conflictInAnotherInstitute();

        Livewire::test('pages::system.sync-conflicts')->assertDontSee(Str::limit($other->row_uuid, 13));

        try {
            Livewire::test('pages::system.sync-conflicts')->call('overturn', $other->uuid);
            $this->fail('التعارض خارج المعهد كان قابلاً للقلب.');
        } catch (ModelNotFoundException) {
            // المطلوب: لا يُعثر عليه أصلاً — لا رفضٌ بعد قراءته
        }

        $this->assertNull($other->fresh()->resolved_at);
    }

    public function test_overturning_writes_the_device_value_into_the_attendance_row(): void
    {
        Livewire::test('pages::system.sync-conflicts')->call('overturn', $this->conflict->uuid);

        $this->assertSame(AttendanceStatus::Present, $this->attendance->fresh()->status);
        $this->assertSame('client_wins', $this->conflict->fresh()->resolution);
        $this->assertSame($this->admin->id, $this->conflict->fresh()->reviewed_by);
        $this->assertNotNull($this->conflict->fresh()->resolved_at);
    }

    /**
     * القلب كتابةٌ جديدة وقعت الآن: لو حملت recorded_at القديم لبقيت أقدمَ من القيمة
     * التي أزاحتها، فتقلبها أوّلُ دفعةٍ لاحقة من الجهاز الآخر.
     */
    public function test_overturning_stamps_the_row_with_the_moment_of_the_decision(): void
    {
        Livewire::test('pages::system.sync-conflicts')->call('overturn', $this->conflict->uuid);

        $this->assertTrue($this->attendance->fresh()->recorded_at->gt(Carbon::parse('2026-09-07 09:30:00')));
    }

    /**
     * التغيير يجب أن يصل الأجهزة: القلب يمرّ بـ TakeAttendance فيلتقطه مراقب Syncable،
     * ولو كتبناه في الصفّ مباشرةً لبقي حبيس اللوحة.
     */
    public function test_overturning_reaches_the_devices_through_the_change_log(): void
    {
        Livewire::test('pages::system.sync-conflicts')->call('overturn', $this->conflict->uuid);

        $this->assertDatabaseHas('change_log', [
            'table_name' => 'attendances',
            'row_uuid' => $this->attendance->uuid,
            'operation' => 'update',
        ]);
    }

    public function test_a_locked_session_refuses_the_overturn_and_says_why(): void
    {
        $this->attendance->attendanceSession->update(['status' => SessionStatus::Locked]);

        Livewire::test('pages::system.sync-conflicts')->call('overturn', $this->conflict->uuid);

        $this->assertSame(AttendanceStatus::Absent, $this->attendance->fresh()->status);
        $this->assertSame('server_wins', $this->conflict->fresh()->resolution);
        $this->assertNull($this->conflict->fresh()->resolved_at);
    }

    public function test_keeping_the_server_value_marks_the_conflict_without_writing_anything(): void
    {
        Livewire::test('pages::system.sync-conflicts')->call('markReviewed', $this->conflict->uuid);

        $this->assertSame(AttendanceStatus::Absent, $this->attendance->fresh()->status);
        $this->assertSame('server_wins', $this->conflict->fresh()->resolution);
        $this->assertNotNull($this->conflict->fresh()->resolved_at);
    }

    private function conflictInAnotherInstitute(): SyncConflict
    {
        $institute = Institute::factory()->create();
        $course = Course::factory()->current()->create(['institute_id' => $institute->id]);
        $circle = Circle::factory()->create(['institute_id' => $institute->id]);
        $shift = Shift::factory()->create(['course_id' => $course->id]);

        $courseCircle = CourseCircle::factory()->create([
            'course_id' => $course->id,
            'circle_id' => $circle->id,
            'shift_id' => $shift->id,
        ]);

        $student = Student::factory()->create(['institute_id' => $institute->id]);

        $session = AttendanceSession::factory()->create([
            'course_circle_id' => $courseCircle->id,
            'session_date' => Carbon::today()->toDateString(),
        ]);

        $attendance = Attendance::factory()->create([
            'attendance_session_id' => $session->id,
            'student_id' => $student->id,
            'status' => AttendanceStatus::Absent,
        ]);

        return SyncConflict::create([
            'institute_id' => $institute->id,
            'table_name' => 'attendances',
            'row_uuid' => $attendance->uuid,
            'server_payload' => $attendance->toArray(),
            'client_payload' => ['status' => AttendanceStatus::Present->value],
            'resolution' => 'server_wins',
        ]);
    }
}
