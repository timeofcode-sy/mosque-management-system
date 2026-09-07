<?php

namespace Tests\Feature\Livewire;

use App\Enums\EnrollmentStatus;
use App\Enums\NotePolarity;
use App\Enums\RecitationGrade;
use App\Models\AttendanceSession;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\MemorizationLog;
use App\Models\Student;
use App\Models\StudentPoint;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Features\SupportTesting\Testable;
use Livewire\Livewire;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class SessionRecitationTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private CourseCircle $courseCircle;

    private Student $student;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
        $this->courseCircle = $this->makeCourseCircle('حلقة الفاروق');
        $this->student = $this->enroll();
    }

    public function test_the_form_defaults_to_juz_thirty_and_the_whole_surah(): void
    {
        $component = $this->recitations()->call('openRecitation');

        $this->assertSame(30, $component->get('juz'));
        $this->assertSame(78, $component->get('fromSurah'));
        $this->assertSame(78, $component->get('toSurah'));
        $this->assertSame(1, $component->get('fromAyah'));
        $this->assertSame(40, $component->get('toAyah'));
    }

    public function test_the_form_suggests_the_first_uncovered_stretch(): void
    {
        MemorizationLog::factory()->create([
            'student_id' => $this->student->id,
            'juz' => 29,
            'from_surah' => 67, 'from_ayah' => 1, 'to_surah' => 67, 'to_ayah' => 12,
        ]);

        $component = $this->recitations()->call('openRecitation');

        // آخر تسميع كان في الجزء 29، وأول سوره الملك — وقد سُمّع منها 1–12.
        $this->assertSame(29, $component->get('juz'));
        $this->assertSame(67, $component->get('fromSurah'));
        $this->assertSame(13, $component->get('fromAyah'));
        $this->assertSame(30, $component->get('toAyah'));
    }

    public function test_the_surah_lists_are_bounded_by_the_juz(): void
    {
        $component = $this->recitations()->call('openRecitation')->set('juz', 29);

        // الجزء 29 يبدأ بالملك وينتهي بالمرسلات — لا سورة قبله ولا بعده في القائمة.
        $this->assertSame(range(67, 77), $component->get('surahsOfJuz'));

        // و«إلى سورة» لا تعرض ما قبل السورة المختارة.
        $component->set('fromSurah', 71);

        $this->assertSame(range(71, 77), $component->get('toSurahsOfJuz'));
    }

    public function test_moving_the_start_forward_drags_the_end_with_it(): void
    {
        $component = $this->recitations()
            ->call('openRecitation')
            ->set('juz', 29)
            ->set('toSurah', 70)
            ->set('fromSurah', 73);

        // نهايةٌ صارت قبل البداية لا تبقى معروضةً في قائمةٍ لا تحويها.
        $this->assertSame(73, $component->get('toSurah'));
    }

    public function test_a_surah_outside_the_juz_is_refused(): void
    {
        $this->recitations()
            ->call('openRecitation')
            ->set('juz', 29)
            ->set('fromSurah', 2)
            ->call('saveRecitation')
            ->assertHasErrors('fromSurah');

        $this->assertSame(0, MemorizationLog::query()->count());
    }

    public function test_within_one_surah_the_last_ayah_may_not_precede_the_first(): void
    {
        $this->recitations()
            ->call('openRecitation')
            ->set('juz', 29)
            ->set('fromSurah', 67)
            ->set('toSurah', 67)
            ->set('fromAyah', 20)
            ->set('toAyah', 5)
            ->call('saveRecitation')
            ->assertHasErrors('toAyah');

        $this->assertSame(0, MemorizationLog::query()->count());
    }

    public function test_a_range_across_two_surahs_of_the_juz_is_saved_whole(): void
    {
        // الآيةُ 20 بعد الآية 5 عدداً، لكنّ سورتَها بعدها ترتيباً — فالمدى صحيح.
        $this->recitations()
            ->call('openRecitation')
            ->set('juz', 29)
            ->set('fromSurah', 67)
            ->set('toSurah', 68)
            ->set('fromAyah', 20)
            ->set('toAyah', 5)
            ->set('grade', RecitationGrade::Excellent->value)
            ->call('saveRecitation')
            ->assertHasNoErrors();

        $log = MemorizationLog::query()->where('student_id', $this->student->id)->sole();

        $this->assertSame(67, $log->from_surah);
        $this->assertSame(68, $log->to_surah);
        $this->assertSame(20, $log->from_ayah);
        $this->assertSame(5, $log->to_ayah);
    }

    public function test_a_range_across_two_surahs_is_reopened_on_its_own_form(): void
    {
        $log = MemorizationLog::factory()->create([
            'student_id' => $this->student->id,
            'attendance_session_id' => $this->todaySession()->id,
            'juz' => 29,
            'from_surah' => 67, 'from_ayah' => 20, 'to_surah' => 68, 'to_ayah' => 5,
        ]);

        $this->recitations()
            ->call('editRecitation', $log->uuid)
            ->assertSet('juz', 29)
            ->assertSet('fromSurah', 67)
            ->assertSet('toSurah', 68)
            ->assertSet('fromAyah', 20)
            ->assertSet('toAyah', 5);
    }

    public function test_saving_a_recitation_freezes_lines_and_points(): void
    {
        $this->recitations()
            ->call('openRecitation')
            ->set('juz', 29)
            ->set('fromSurah', 67)
            ->set('toSurah', 67)
            ->set('fromAyah', 1)
            ->set('toAyah', 30)
            ->set('grade', RecitationGrade::Excellent->value)
            ->call('saveRecitation')
            ->assertHasNoErrors();

        $log = MemorizationLog::query()->where('student_id', $this->student->id)->sole();

        $this->assertSame(RecitationGrade::Excellent, $log->grade);
        $this->assertEqualsWithDelta(31.0, (float) $log->lines, 0.01);
        $this->assertEqualsWithDelta(31.0, (float) $log->new_lines, 0.01);
        // 31 سطراً ÷ 15 × 10 نقاط × معامل ممتاز (100%)
        $this->assertEqualsWithDelta(20.67, (float) $log->points, 0.01);
    }

    public function test_a_repeated_stretch_earns_nothing_new(): void
    {
        $save = fn (int $from, int $to) => $this->recitations()
            ->call('openRecitation')
            ->set('juz', 29)
            ->set('fromSurah', 67)
            ->set('toSurah', 67)
            ->set('fromAyah', $from)
            ->set('toAyah', $to)
            ->set('grade', RecitationGrade::Excellent->value)
            ->call('saveRecitation');

        $save(1, 12);
        $save(1, 30);

        $second = MemorizationLog::query()->where('student_id', $this->student->id)->latest('id')->firstOrFail();

        // الملك ثلاثون آية في 31 سطراً؛ الجديد 18 آية فقط.
        $this->assertEqualsWithDelta(31.0, (float) $second->lines, 0.01);
        $this->assertEqualsWithDelta(18.6, (float) $second->new_lines, 0.01);
    }

    public function test_the_grade_multiplier_lowers_the_points(): void
    {
        $this->recitations()
            ->call('openRecitation')
            ->set('juz', 29)
            ->set('fromSurah', 67)
            ->set('toSurah', 67)
            ->set('fromAyah', 1)
            ->set('toAyah', 30)
            ->set('grade', RecitationGrade::Good->value)
            ->call('saveRecitation');

        $log = MemorizationLog::query()->where('student_id', $this->student->id)->sole();

        // معامل «جيد» 60% من 20.67
        $this->assertEqualsWithDelta(12.4, (float) $log->points, 0.01);
    }

    public function test_discretionary_points_accept_a_negative_value(): void
    {
        $this->recitations()
            ->call('openPoints')
            ->set('pointReason', 'behavior')
            ->set('pointValue', '-2')
            ->call('savePoints')
            ->assertHasNoErrors();

        $award = StudentPoint::query()->where('student_id', $this->student->id)->sole();

        $this->assertEqualsWithDelta(-2.0, (float) $award->points, 0.01);
        $this->assertSame($this->todaySession()->id, $award->attendance_session_id);
    }

    public function test_a_recorded_recitation_is_corrected_in_place(): void
    {
        $log = $this->record(1, 30);

        $this->recitations()
            ->assertSeeHtml('edit-recitation-'.$log->id)
            ->call('editRecitation', $log->uuid)
            ->assertSet('fromSurah', 67)
            ->assertSet('toSurah', 67)
            ->assertSet('fromAyah', 1)
            ->assertSet('toAyah', 30)
            ->set('toAyah', 12)
            ->set('grade', RecitationGrade::Good->value)
            ->call('saveRecitation')
            ->assertHasNoErrors();

        $log->refresh();

        // سجلٌّ واحد لا سجلّان: التصحيح تعديلٌ لا إضافة.
        $this->assertSame(1, MemorizationLog::query()->where('student_id', $this->student->id)->count());
        $this->assertSame(12, $log->to_ayah);
        $this->assertSame(RecitationGrade::Good, $log->grade);
    }

    public function test_a_corrected_recitation_is_not_a_repeat_of_itself(): void
    {
        $log = $this->record(1, 30);

        $this->recitations()
            ->call('editRecitation', $log->uuid)
            ->call('saveRecitation')
            ->assertHasNoErrors();

        $log->refresh();

        // لو حُسبت الخريطة بالسجلّ نفسه لصار الجديد صفراً والنقاط معه.
        $this->assertEqualsWithDelta(31.0, (float) $log->new_lines, 0.01);
        $this->assertEqualsWithDelta(20.67, (float) $log->points, 0.01);
    }

    public function test_a_recitation_of_another_student_is_refused(): void
    {
        $log = $this->record(1, 30);
        $log->update(['student_id' => $this->enroll()->id]);

        $component = $this->recitations()->call('editRecitation', $log->uuid);

        $this->assertNull($component->get('editingRecitationId'));

        $component->call('deleteRecitation', $log->uuid);

        $this->assertNotNull($log->fresh());
    }

    public function test_a_completed_session_refuses_a_correction_without_the_amend_permission(): void
    {
        $log = $this->record(1, 30);

        Livewire::test('pages::attendance.take', ['courseCircle' => $this->courseCircle])
            ->set('date', '2026-09-01')
            ->call('complete');

        $teacher = User::factory()->create();
        $this->assignRole($teacher, 'teacher');
        $this->actingAs($teacher);

        Livewire::test('session-student-recitations', [
            'student' => $this->student,
            'session' => $this->todaySession(),
            'editable' => false,
        ])
            ->assertDontSeeHtml('edit-recitation-'.$log->id)
            ->call('editRecitation', $log->uuid)
            ->set('toAyah', 12)
            ->call('saveRecitation');

        $this->assertSame(30, $log->fresh()->to_ayah);
    }

    public function test_a_recorded_award_is_corrected_in_place(): void
    {
        $this->recitations()
            ->call('openPoints')
            ->set('pointReason', 'behavior')
            ->set('pointValue', '-2')
            ->call('savePoints');

        $award = StudentPoint::query()->where('student_id', $this->student->id)->sole();

        $this->recitations()
            ->call('editAward', $award->uuid)
            ->assertSet('pointReason', 'behavior')
            ->assertSet('pointValue', '-2')
            ->set('pointValue', '-5')
            ->set('pointNote', 'خصم مصحَّح')
            ->call('savePoints')
            ->assertHasNoErrors();

        $award->refresh();

        $this->assertSame(1, StudentPoint::query()->where('student_id', $this->student->id)->count());
        $this->assertEqualsWithDelta(-5.0, (float) $award->points, 0.01);
        $this->assertSame('خصم مصحَّح', $award->note);
    }

    public function test_a_note_is_saved_with_its_polarity(): void
    {
        Livewire::test('pages::attendance.take', ['courseCircle' => $this->courseCircle])
            ->set('date', '2026-09-01')
            ->call('openNote', $this->student->id)
            ->set("rows.{$this->student->id}.note", 'شغب في الحلقة')
            ->set("rows.{$this->student->id}.note_polarity", NotePolarity::Negative->value)
            ->call('saveNote')
            ->assertHasNoErrors();

        $attendance = $this->todaySession()->attendances()->where('student_id', $this->student->id)->sole();

        $this->assertSame('شغب في الحلقة', $attendance->note);
        $this->assertSame(NotePolarity::Negative, $attendance->note_polarity);
    }

    public function test_a_teacher_never_sees_the_lock_button(): void
    {
        $teacher = User::factory()->create();
        $this->assignRole($teacher, 'teacher');
        $this->actingAs($teacher);

        $component = Livewire::test('pages::attendance.take', ['courseCircle' => $this->courseCircle])
            ->set('date', '2026-09-01')
            ->call('complete');

        $this->assertFalse($component->instance()->canLock());
        $component->assertDontSee('قفل نهائي');

        // وإن استُدعيت الدالة مباشرةً رُفضت على الخادم لا في الواجهة فقط.
        $component->call('lock');

        $this->assertSame('completed', $this->todaySession()->status->value);
    }

    public function test_a_supervisor_locks_the_session(): void
    {
        $supervisor = User::factory()->create();
        $this->assignRole($supervisor, 'supervisor');
        $this->actingAs($supervisor);

        Livewire::test('pages::attendance.take', ['courseCircle' => $this->courseCircle])
            ->set('date', '2026-09-01')
            ->call('complete')
            ->call('lock');

        $this->assertSame('locked', $this->todaySession()->status->value);
    }

    public function test_a_locked_session_refuses_a_new_recitation(): void
    {
        Livewire::test('pages::attendance.take', ['courseCircle' => $this->courseCircle])
            ->set('date', '2026-09-01')
            ->call('complete')
            ->call('lock');

        $this->recitations()
            ->call('openRecitation')
            ->set('juz', 29)
            ->set('fromSurah', 67)
            ->set('toSurah', 67)
            ->set('fromAyah', 1)
            ->set('toAyah', 30)
            ->set('grade', RecitationGrade::Excellent->value)
            ->call('saveRecitation');

        $this->assertSame(0, MemorizationLog::query()->count());
    }

    /**
     * تسميع مسجَّل في سورة الملك — أرضيّةُ اختبارات التصحيح.
     */
    private function record(int $from, int $to): MemorizationLog
    {
        $this->recitations()
            ->call('openRecitation')
            ->set('juz', 29)
            ->set('fromSurah', 67)
            ->set('toSurah', 67)
            ->set('fromAyah', $from)
            ->set('toAyah', $to)
            ->set('grade', RecitationGrade::Excellent->value)
            ->call('saveRecitation');

        return MemorizationLog::query()->where('student_id', $this->student->id)->latest('id')->firstOrFail();
    }

    private function recitations(): Testable
    {
        return Livewire::test('session-student-recitations', [
            'student' => $this->student,
            'session' => $this->todaySession(),
            'editable' => true,
        ]);
    }

    private function todaySession(): AttendanceSession
    {
        return $this->courseCircle->attendanceSessions()->whereDate('session_date', '2026-09-01')->sole();
    }

    private function enroll(): Student
    {
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);

        Enrollment::factory()->create([
            'course_circle_id' => $this->courseCircle->id,
            'student_id' => $student->id,
            'status' => EnrollmentStatus::Active,
            'enrolled_on' => '2026-08-01',
        ]);

        // فتح جلسة اليوم المختبَر مرّةً واحدة، فتُشارَك بين الشاشة والمكوّن المتداخل.
        Livewire::test('pages::attendance.take', ['courseCircle' => $this->courseCircle])->set('date', '2026-09-01');

        return $student;
    }
}
