<?php

namespace App\Actions;

use App\Models\Circle;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\Shift;
use RuntimeException;

/**
 * تشغيلُ حلقةٍ ضمن دورةٍ ودوام — الصفُّ الذي تُعلَّق عليه الجلساتُ والتسجيلات.
 *
 * الحلقةُ هويّةٌ ثابتة عبر الدورات (`circles`)، وتشغيلُها في دورةٍ صفٌّ مستقل
 * (`course_circles`) — فسجلُّ الدورة الماضية يبقى قائماً بعد أن تنتهي.
 *
 * الحراسةُ هنا لا في الشاشة: الديسكتوب يرسل معرّفات، ودوامٌ من دورةٍ أخرى كان
 * سيُنتج صفّاً لا معنى له بلا أن يشتكي أحد.
 */
class RunCircleInCourse
{
    public function handle(Course $course, Circle $circle, Shift $shift, ?string $room = null, ?int $capacity = null): CourseCircle
    {
        if ($shift->course_id !== $course->id) {
            throw new RuntimeException('الدوام المختار ليس من هذه الدورة.');
        }

        if ($circle->institute_id !== $course->institute_id) {
            throw new RuntimeException('الحلقة المختارة ليست من معهد هذه الدورة.');
        }

        // قيدُ (course_id, circle_id) في الهجرة: الحلقةُ تعمل مرّةً واحدة في الدورة.
        // يُفحص هنا لتعود رسالةٌ مقروءة بدل انتهاكِ قيدٍ يظهر 500.
        $exists = CourseCircle::query()
            ->where('course_id', $course->id)
            ->where('circle_id', $circle->id)
            ->exists();

        if ($exists) {
            throw new RuntimeException('هذه الحلقة تعمل في هذه الدورة أصلاً.');
        }

        return CourseCircle::create([
            'course_id' => $course->id,
            'circle_id' => $circle->id,
            'shift_id' => $shift->id,
            'room' => $room,
            'capacity' => $capacity,
        ]);
    }
}
