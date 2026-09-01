<?php

namespace App\Actions;

use App\Enums\CourseStatus;
use App\Models\Course;
use Illuminate\Support\Facades\DB;

/**
 * جعل دورة هي الجارية — دورة واحدة فقط لكل معهد تحمل is_current.
 */
class ActivateCourse
{
    public function handle(Course $course): Course
    {
        return DB::transaction(function () use ($course): Course {
            Course::query()
                ->where('institute_id', $course->institute_id)
                ->whereKeyNot($course->id)
                ->update(['is_current' => false]);

            $course->update([
                'is_current' => true,
                'status' => CourseStatus::Active,
            ]);

            return $course->refresh();
        });
    }
}
