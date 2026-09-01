<?php

namespace App\Actions;

use App\Enums\TeacherRole;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Shift;
use App\Models\ShiftDay;
use Illuminate\Support\Facades\DB;

/**
 * استنساخ بنية دورة سابقة (الدوامات وأيامها، الحلقات المشغَّلة، أساتذتها) إلى دورة جديدة.
 *
 * لا يُنسخ أي تسجيل ولا تفقّد — هذا بالضبط ما يجعل عدّادات الغياب تبدأ من الصفر
 * مع كل دورة بينما يبقى سجل الدورة السابقة سليماً.
 */
class CloneCourseCircles
{
    /**
     * @return array{shifts: int, circles: int, teachers: int}
     */
    public function handle(Course $source, Course $target): array
    {
        return DB::transaction(function () use ($source, $target): array {
            $shiftMap = $this->cloneShifts($source, $target);

            return $this->cloneCourseCircles($source, $target, $shiftMap);
        });
    }

    /**
     * @return array<int, int> معرّف الدوام في الدورة المصدر ⇒ معرّفه في الدورة الهدف
     */
    private function cloneShifts(Course $source, Course $target): array
    {
        $existing = $target->shifts()->get()->keyBy('name');
        $map = [];

        foreach ($source->shifts()->with('days')->orderBy('sort_order')->get() as $shift) {
            $clone = $existing->get($shift->name);

            if ($clone === null) {
                $clone = Shift::create([
                    'course_id' => $target->id,
                    'name' => $shift->name,
                    'starts_at' => $shift->starts_at,
                    'ends_at' => $shift->ends_at,
                    'sort_order' => $shift->sort_order,
                    'is_active' => $shift->is_active,
                ]);

                foreach ($shift->days as $day) {
                    ShiftDay::create(['shift_id' => $clone->id, 'weekday' => $day->weekday]);
                }
            }

            $map[$shift->id] = $clone->id;
        }

        return $map;
    }

    /**
     * @param  array<int, int>  $shiftMap
     * @return array{shifts: int, circles: int, teachers: int}
     */
    private function cloneCourseCircles(Course $source, Course $target, array $shiftMap): array
    {
        $alreadyRunning = $target->courseCircles()->pluck('circle_id')->all();
        $circles = 0;
        $teachers = 0;

        $sourceCircles = $source->courseCircles()
            ->with('courseCircleTeachers')
            ->whereNotIn('circle_id', $alreadyRunning)
            ->get();

        foreach ($sourceCircles as $courseCircle) {
            $clone = CourseCircle::create([
                'course_id' => $target->id,
                'circle_id' => $courseCircle->circle_id,
                'shift_id' => $shiftMap[$courseCircle->shift_id] ?? $courseCircle->shift_id,
                'room' => $courseCircle->room,
                'capacity' => $courseCircle->capacity,
                'status' => $courseCircle->status,
            ]);

            $circles++;

            foreach ($courseCircle->courseCircleTeachers->whereNull('left_on') as $assignment) {
                CourseCircleTeacher::create([
                    'course_circle_id' => $clone->id,
                    'teacher_id' => $assignment->teacher_id,
                    'role' => $assignment->role ?? TeacherRole::Main,
                    'joined_on' => $target->starts_on,
                ]);

                $teachers++;
            }
        }

        return ['shifts' => count($shiftMap), 'circles' => $circles, 'teachers' => $teachers];
    }
}
