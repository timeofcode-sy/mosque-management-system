<?php

namespace App\Actions;

use App\Models\Course;
use App\Models\Shift;
use App\Models\ShiftDay;
use Illuminate\Support\Facades\DB;

/**
 * إنشاء دوام أو تحريره مع أيامه الأسبوعية.
 *
 * الأيام تُحذف وتُعاد كتابتُها لا تُزامَن بـ`sync()`: `shift_days` جدولٌ يحمل uuid
 * ويُبثّ في تيّار التغييرات، فالكتابةُ تمرّ بالنموذج ليراها المراقب
 * ([SYNC-PROTOCOL.md §2]).
 *
 * أُخرج من شاشة الدوامات في م.6.2 ليستدعيه السطحان — [ARCHITECTURE.md §3].
 */
class SaveShift
{
    /**
     * @param  array<string, mixed>  $attributes  name · starts_at · ends_at · sort_order? · is_active?
     * @param  array<int, int>  $weekdays  0..6
     */
    public function handle(Course $course, array $attributes, array $weekdays, ?Shift $shift = null): Shift
    {
        return DB::transaction(function () use ($course, $attributes, $weekdays, $shift): Shift {
            $shift ??= new Shift;

            $shift->fill([...$attributes, 'course_id' => $course->id])->save();

            $shift->days()->delete();

            foreach (array_unique(array_map('intval', $weekdays)) as $weekday) {
                ShiftDay::create(['shift_id' => $shift->id, 'weekday' => $weekday]);
            }

            return $shift->refresh();
        });
    }
}
