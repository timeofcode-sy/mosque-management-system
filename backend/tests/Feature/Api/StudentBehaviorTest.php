<?php

namespace Tests\Feature\Api;

use App\Enums\GuardianRelation;
use App\Enums\NotePolarity;
use App\Enums\PointReason;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\GuardianStudent;
use App\Models\PersonalTrait;
use App\Models\Student;
use App\Models\StudentPoint;
use App\Models\StudentTrait;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\App;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\PermissionRegistrar;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * الجانب السلوكي يقرؤه وليُّ الأمر عن ابنه والطالبُ عن نفسه — ولا يقرأ أحدُهما غيرَ ما له.
 */
class StudentBehaviorTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    private Student $student;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
        $this->student = Student::factory()->create(['institute_id' => $this->institute->id]);

        $courseCircle = $this->makeCourseCircle();

        foreach ([
            ['2026-10-01', 'يساعد زملاءه في الحفظ', NotePolarity::Positive],
            ['2026-10-05', 'تأخّر عن الحلقة وتحدّث أثناء التسميع', NotePolarity::Negative],
            ['2026-10-08', 'أحضر مصحفه الجديد', null],
            ['2026-10-09', null, null],
        ] as [$date, $note, $polarity]) {
            Attendance::factory()->create([
                'attendance_session_id' => AttendanceSession::factory()->completed()->create([
                    'course_circle_id' => $courseCircle->id,
                    'session_date' => $date,
                ])->id,
                'student_id' => $this->student->id,
                'note' => $note,
                'note_polarity' => $polarity,
            ]);
        }

        StudentTrait::create([
            'student_id' => $this->student->id,
            'trait_id' => PersonalTrait::factory()->create(['name' => 'هادئ', 'polarity' => 'positive'])->id,
            'note' => 'في الحلقة خاصّة',
        ]);

        StudentPoint::factory()->create([
            'student_id' => $this->student->id,
            'reason' => PointReason::Behavior,
            'points' => 5,
            'note' => 'نظّف المصلّى',
            'awarded_on' => '2026-10-07',
        ]);
        StudentPoint::factory()->create([
            'student_id' => $this->student->id,
            'reason' => PointReason::Competition,
            'points' => 20,
        ]);
    }

    public function test_a_guardian_reads_the_behaviour_of_their_child(): void
    {
        $guardian = $this->actingAsGuardian();

        GuardianStudent::create([
            'guardian_id' => $guardian->id,
            'student_id' => $this->student->id,
            'relation' => GuardianRelation::Father,
        ]);

        $response = $this->getJson("/api/v1/guardian/children/{$this->student->uuid}/behavior")->assertOk();

        $response->assertJsonPath('summary.positive', 1)
            ->assertJsonPath('summary.negative', 1)
            ->assertJsonPath('summary.neutral', 1)
            ->assertJsonPath('traits.0.name', 'هادئ')
            ->assertJsonPath('traits.0.note', 'في الحلقة خاصّة')
            ->assertJsonPath('points.0.note', 'نظّف المصلّى');

        // الأحدث أولاً، والتفقّدُ بلا ملاحظةٍ ليس ملاحظة، ونقاطُ المسابقة ليست سلوكاً.
        $this->assertSame(['2026-10-08', '2026-10-05', '2026-10-01'], array_column($response->json('notes'), 'date'));
        $this->assertSame([null, 'negative', 'positive'], array_column($response->json('notes'), 'polarity'));
        $this->assertEquals(5, $response->json('summary.behavior_points'));
        $this->assertCount(1, $response->json('points'));
    }

    public function test_a_guardian_cannot_read_someone_elses_child(): void
    {
        $this->actingAsGuardian();

        $this->getJson("/api/v1/guardian/children/{$this->student->uuid}/behavior")->assertNotFound();
    }

    public function test_a_student_reads_their_own_behaviour(): void
    {
        $user = User::factory()->create();
        $this->student->update(['user_id' => $user->id]);

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($this->institute->id);
        $user->assignRole('student');
        Sanctum::actingAs($user, ['*']);

        $this->getJson('/api/v1/student/me/behavior')
            ->assertOk()
            ->assertJsonPath('summary.positive', 1)
            ->assertJsonCount(3, 'notes');
    }
}
