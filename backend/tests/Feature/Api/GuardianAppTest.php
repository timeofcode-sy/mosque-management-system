<?php

namespace Tests\Feature\Api;

use App\Enums\AttendanceStatus;
use App\Enums\ExcuseStatus;
use App\Enums\GuardianRelation;
use App\Models\AbsenceExcuse;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\Curriculum;
use App\Models\CurriculumItem;
use App\Models\Guardian;
use App\Models\GuardianStudent;
use App\Models\Student;
use App\Models\StudentCurriculumProgress;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Role;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * عقدُ سطح ولي الأمر — م.7.1.
 *
 * ما يحرسه: أن يكون لكلّ ما تعرضه شاشاتُ التطبيق الخمس نقطةٌ تعيده، وأن يبقى
 * وليُّ الأمر محصوراً في أبنائه، وأن **لا يُفترض ما لم يُسجَّل** في المنحنى.
 */
class GuardianAppTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
    }

    public function test_a_guardian_reads_their_children_and_no_one_elses(): void
    {
        $guardian = $this->actingAsGuardian();
        $mine = $this->childOf($guardian);
        $theirs = Student::factory()->create(['institute_id' => $this->institute->id]);

        $uuids = collect($this->getJson('/api/v1/guardian/children')->assertOk()->json('data'))
            ->pluck('uuid')->all();

        $this->assertContains($mine->uuid, $uuids);
        $this->assertNotContains($theirs->uuid, $uuids);
    }

    /**
     * 🔄 م.7.1: الشكلُ صار `{summary, trend, recent}` — شكلَ `/student/me/attendance`
     * نفسَه، فلا يُحسب رقمُ النسبة مرّتين لجمهورين.
     */
    public function test_child_attendance_returns_the_summary_the_trend_and_the_record(): void
    {
        $guardian = $this->actingAsGuardian();
        $child = $this->childOf($guardian);

        $this->attendanceFor($child, Carbon::today(), AttendanceStatus::Present);

        $response = $this->getJson("/api/v1/guardian/children/{$child->uuid}/attendance")->assertOk();

        $response->assertJsonStructure([
            'summary' => ['present', 'absent', 'late', 'excused', 'total', 'rate'],
            'trend',
            'recent',
        ]);
        // assertEquals لا assertSame: `json_encode(100.0) === '100'` فيعود العددُ
        // صحيحاً لا عشرياً — القاعدةُ نفسُها الموثَّقة في [API.md §3.4].
        $this->assertEquals(100.0, $response->json('summary.rate'));
        $this->assertCount(30, $response->json('trend'));
    }

    /**
     * 🔴 الحاجبُ الذي فتح م.7.1: وليُّ الأمر يقرأ الحضورَ **يوماً بيوم**، وكان
     * المورد يعيد `recorded_at` وحده — لحظةَ كتابة الأستاذ لا يومَ الحضور.
     */
    public function test_each_attendance_row_carries_the_day_it_belongs_to(): void
    {
        $guardian = $this->actingAsGuardian();
        $child = $this->childOf($guardian);

        $yesterday = Carbon::yesterday();
        $attendance = $this->attendanceFor($child, $yesterday, AttendanceStatus::Present);

        // الأستاذُ يصحّح جلسةَ أمس اليوم: recorded_at اليومُ، والجلسةُ أمس.
        $attendance->forceFill(['recorded_at' => Carbon::now()])->save();

        $row = $this->getJson("/api/v1/guardian/children/{$child->uuid}/attendance")
            ->assertOk()->json('recent.0');

        $this->assertSame($yesterday->toDateString(), $row['session_date']);
    }

    /**
     * 🔑 قاعدةُ م.6.6 على السطح الخادمي: ما لم يُسجَّل لا يُفترض.
     */
    public function test_a_day_without_a_session_has_a_null_rate_not_a_zero(): void
    {
        $guardian = $this->actingAsGuardian();
        $child = $this->childOf($guardian);

        $this->attendanceFor($child, Carbon::today(), AttendanceStatus::Present);

        $trend = collect($this->getJson("/api/v1/guardian/children/{$child->uuid}/attendance")
            ->assertOk()->json('trend'));

        $today = $trend->firstWhere('date', Carbon::today()->toDateString());
        $empty = $trend->firstWhere('date', Carbon::today()->subDays(10)->toDateString());

        $this->assertEquals(100.0, $today['rate']);
        $this->assertSame(1, $today['sessions']);
        // والفرقُ الذي تحرسه هذه المرحلة: null لا صفر.
        $this->assertNull($empty['rate']);
        $this->assertSame(0, $empty['sessions']);
    }

    /**
     * ويومٌ كلُّ سجلّاته «مأذون» لا مقامَ له — فلا نسبةَ له.
     */
    public function test_a_fully_excused_day_has_a_null_rate_too(): void
    {
        $guardian = $this->actingAsGuardian();
        $child = $this->childOf($guardian);

        $this->attendanceFor($child, Carbon::today(), AttendanceStatus::Excused);

        $today = collect($this->getJson("/api/v1/guardian/children/{$child->uuid}/attendance")
            ->assertOk()->json('trend'))
            ->firstWhere('date', Carbon::today()->toDateString());

        $this->assertNull($today['rate']);
        $this->assertSame(1, $today['sessions']);
    }

    public function test_a_guardian_reads_the_memorisation_progress_of_their_child(): void
    {
        $guardian = $this->actingAsGuardian();
        $child = $this->childOf($guardian);

        $curriculum = Curriculum::factory()->create([
            'institute_id' => $this->institute->id,
            'name' => 'القرآن الكريم',
        ]);
        $item = CurriculumItem::factory()->create([
            'curriculum_id' => $curriculum->id,
            'name' => 'جزء عمّ',
        ]);
        StudentCurriculumProgress::factory()->memorized()->create([
            'student_id' => $child->id,
            'curriculum_item_id' => $item->id,
        ]);

        $data = $this->getJson("/api/v1/guardian/children/{$child->uuid}/progress")
            ->assertOk()->json('data');

        $this->assertArrayHasKey('القرآن الكريم', $data);
        $entry = $data['القرآن الكريم'][0];

        $this->assertSame('جزء عمّ', $entry['item_name']);
        $this->assertSame('محفوظ', $entry['status_label']);

        // ولا مفتاحَ داخلياً في الخرج — ProgressResource أغلق النموذجَ الخام.
        $this->assertArrayNotHasKey('student_id', $entry);
        $this->assertArrayNotHasKey('curriculum_item_id', $entry);
    }

    /**
     * 🔴 م.7.4 — **الحالةُ الفارغة تبقى كائناً `{}` لا تصير مصفوفةً `[]`**.
     *
     * `groupBy` على مجموعةٍ فارغة يخرج من `json_encode` مصفوفةً، فيبدّل الحقلُ
     * **نوعَه** بحسب محتواه ويرمي العميلُ عند فكّ الحمولة. وطالبٌ جديد بلا
     * محفوظاتٍ هو الحالةُ الأغلب لا النادرة.
     *
     * كُشف بتجريبٍ على المحاكي: النقطةُ ردّت 200 والشاشةُ عرضت «حدث خطأ غير
     * متوقّع». ولم يكشفه الاختبارُ الذي فوقه لأنه **ينشئ صفَّ تقدُّمٍ قبل
     * القراءة** — فالحالةُ الفارغة لم تُختبَر أصلاً.
     */
    public function test_a_child_with_no_progress_still_returns_an_object_not_an_array(): void
    {
        $guardian = $this->actingAsGuardian();
        $child = $this->childOf($guardian);

        $raw = $this->getJson("/api/v1/guardian/children/{$child->uuid}/progress")
            ->assertOk()
            ->getContent();

        $this->assertStringContainsString('"data":{}', $raw);
        $this->assertStringNotContainsString('"data":[]', $raw);
    }

    /**
     * ✅ م.7.1 — النقطةُ التي حلّت محلّ `sync/pull` عند ولي الأمر: بدونها يقدّم
     * إذناً ثم لا يرى جوابَ الطاقم عليه أبداً.
     */
    public function test_a_guardian_follows_the_verdict_on_the_excuse_they_submitted(): void
    {
        $guardian = $this->actingAsGuardian();
        $child = $this->childOf($guardian);

        $this->postJson('/api/v1/guardian/excuses', [
            'student_uuid' => $child->uuid,
            'from_date' => Carbon::tomorrow()->toDateString(),
            'to_date' => Carbon::tomorrow()->addDay()->toDateString(),
            'reason' => 'سفر عائلي',
        ])->assertCreated()->assertJsonPath('status', ExcuseStatus::Pending->value);

        $pending = $this->getJson('/api/v1/guardian/excuses')->assertOk()->json('data.0');

        $this->assertSame($child->uuid, $pending['student_uuid']);
        $this->assertSame('قيد المراجعة', $pending['status_label']);

        // ثم يراجعه الطاقمُ من اللوحة برفضٍ مُعلَّل — فيصل التعليلُ إلى الأب.
        AbsenceExcuse::query()->latest('id')->first()->forceFill([
            'status' => ExcuseStatus::Rejected,
            'reviewed_at' => Carbon::now(),
            'review_note' => 'الدورة في أيامها الأخيرة.',
        ])->save();

        $reviewed = $this->getJson('/api/v1/guardian/excuses')->assertOk()->json('data.0');

        $this->assertSame('مرفوض', $reviewed['status_label']);
        $this->assertSame('الدورة في أيامها الأخيرة.', $reviewed['review_note']);
    }

    /**
     * الإذنُ الذي يقدّمه المشرفُ نيابةً عنه — حين يصل هاتفياً — إذنٌ عن ابنه
     * يحقّ له أن يتابعه ولو لم يكتبه هو.
     */
    public function test_the_excuse_list_follows_the_child_not_the_submitter(): void
    {
        $guardian = $this->actingAsGuardian();
        $child = $this->childOf($guardian);

        AbsenceExcuse::factory()->create([
            'student_id' => $child->id,
            'submitted_by' => $this->admin->id,
        ]);

        $this->getJson('/api/v1/guardian/excuses')->assertOk()->assertJsonCount(1, 'data');
    }

    /**
     * الحصرُ في الاستعلام لا في العرض: 404 لا 403، فلا يؤكّد الجوابُ وجودَ الطالب.
     */
    public function test_every_child_scoped_endpoint_rejects_a_child_that_is_not_theirs(): void
    {
        $this->actingAsGuardian();
        $theirs = Student::factory()->create(['institute_id' => $this->institute->id]);

        $this->getJson("/api/v1/guardian/children/{$theirs->uuid}/attendance")->assertNotFound();
        $this->getJson("/api/v1/guardian/children/{$theirs->uuid}/progress")->assertNotFound();
        $this->postJson('/api/v1/guardian/excuses', [
            'student_uuid' => $theirs->uuid,
            'from_date' => Carbon::tomorrow()->toDateString(),
            'to_date' => Carbon::tomorrow()->toDateString(),
            'reason' => 'محاولة',
        ])->assertNotFound();
    }

    public function test_a_guardian_with_no_children_gets_empty_lists_not_an_error(): void
    {
        $this->actingAsGuardian();

        $this->getJson('/api/v1/guardian/children')->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/guardian/excuses')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_an_account_that_is_not_a_guardian_record_is_told_so(): void
    {
        $user = User::factory()->create();
        $this->assignInstituteRole($user, $this->institute, 'guardian');
        Sanctum::actingAs($user, ['*']);

        $this->getJson('/api/v1/guardian/children')
            ->assertNotFound()
            ->assertJsonPath('message', 'هذا الحساب ليس حساب ولي أمر.');
    }

    /**
     * القرارُ 0.3: نُزعت `reports.view` من الدور، فلا يفتح تقاريرَ المعهد في اللوحة.
     */
    public function test_a_guardian_no_longer_holds_the_panel_reports_permission(): void
    {
        $this->assertFalse(Role::findByName('guardian')->hasPermissionTo('reports.view'));
        $this->assertTrue(Role::findByName('guardian')->hasPermissionTo('excuses.submit'));
    }

    /**
     * القرارُ 0.1 مقروءاً من الجهة الأخرى: لقطةُ الإقلاع تكفي وليَّ الأمر بلا
     * حلقات — شاشتُه الأولى أبناؤه، ويكفيه منها المعهدُ وثيمُه.
     */
    public function test_the_bootstrap_snapshot_serves_a_guardian_without_circles(): void
    {
        $this->actingAsGuardian();

        $this->getJson('/api/v1/bootstrap')
            ->assertOk()
            ->assertJsonPath('circles', [])
            ->assertJsonPath('user.roles', ['guardian'])
            ->assertJsonStructure([
                'institute' => ['name', 'theme' => ['primary', 'secondary', 'surface']],
            ]);
    }

    /**
     * الربطُ بـ`GuardianStudent::create` لا بـ`attach` على العلاقة: الجدولُ
     * الوسيط نموذجٌ يحمل `HasUuid`، و`attach` يكتب صفّاً خاماً بلا `uuid` فيسقط
     * على قيد `NOT NULL`. وهو نفسُ ما تفعله `ScopeTest`.
     */
    private function childOf(Guardian $guardian): Student
    {
        $child = Student::factory()->create(['institute_id' => $this->institute->id]);

        GuardianStudent::create([
            'guardian_id' => $guardian->id,
            'student_id' => $child->id,
            'relation' => GuardianRelation::Father,
            'is_primary' => true,
            'can_view_reports' => true,
            'can_submit_excuses' => true,
        ]);

        return $child;
    }

    private function attendanceFor(Student $student, Carbon $date, AttendanceStatus $status): Attendance
    {
        $session = AttendanceSession::factory()->completed()->create([
            'course_circle_id' => $this->makeCourseCircle()->id,
            'session_date' => $date,
        ]);

        return Attendance::factory()->create([
            'attendance_session_id' => $session->id,
            'student_id' => $student->id,
            'status' => $status,
            'recorded_at' => $date->copy()->setTime(8, 0),
        ]);
    }
}
