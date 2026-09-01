<?php

namespace App\Actions;

use App\Enums\EnrollmentStatus;
use App\Models\CourseCircle;
use App\Models\Enrollment;
use App\Models\Student;
use App\Models\StudentTransfer;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * نقل طالب بين حلقتين ضمن الدورة نفسها.
 *
 * التسجيل القديم يُغلق بحالة "منقول" ولا يُحذف، فيبقى سجل الحضور المرتبط به قابلاً
 * للاستعلام بينما يختفي الطالب من تفقّد الحلقة القديمة.
 */
class TransferStudent
{
    public function handle(
        Student $student,
        CourseCircle $to,
        ?string $reason = null,
        ?User $performedBy = null,
        ?string $transferredOn = null,
    ): Enrollment {
        $from = $this->activeEnrollmentInCourse($student, $to);

        if ($from->course_circle_id === $to->id) {
            throw new RuntimeException('الطالب مسجَّل في هذه الحلقة أصلاً.');
        }

        $date = $transferredOn ?? Carbon::today()->toDateString();

        return DB::transaction(function () use ($student, $from, $to, $reason, $performedBy, $date): Enrollment {
            $from->update([
                'status' => EnrollmentStatus::Transferred,
                'left_on' => $date,
            ]);

            $enrollment = Enrollment::create([
                'course_circle_id' => $to->id,
                'student_id' => $student->id,
                'status' => EnrollmentStatus::Active,
                'enrolled_on' => $date,
            ]);

            StudentTransfer::create([
                'student_id' => $student->id,
                'course_id' => $to->course_id,
                'from_course_circle_id' => $from->course_circle_id,
                'to_course_circle_id' => $to->id,
                'transferred_on' => $date,
                'reason' => $reason,
                'performed_by' => $performedBy?->id,
            ]);

            return $enrollment;
        });
    }

    private function activeEnrollmentInCourse(Student $student, CourseCircle $to): Enrollment
    {
        $enrollment = Enrollment::query()
            ->where('student_id', $student->id)
            ->where('status', EnrollmentStatus::Active)
            ->whereHas('courseCircle', fn ($query) => $query->where('course_id', $to->course_id))
            ->first();

        if ($enrollment === null) {
            throw new RuntimeException('لا يوجد تسجيل جارٍ للطالب في هذه الدورة.');
        }

        return $enrollment;
    }
}
