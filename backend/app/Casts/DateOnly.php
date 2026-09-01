<?php

namespace App\Casts;

use Illuminate\Contracts\Database\Eloquent\CastsAttributes;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * عمود تاريخ بلا وقت — يُقرأ Carbon ويُكتب دائماً 'Y-m-d'.
 *
 * ضروري لأن صيغة الطبع في `date:Y-m-d` تحكم التسلسل إلى JSON فقط، أما الكتابة
 * فتمرّ بـ fromDateTime() فتُخزَّن 'Y-m-d H:i:s'. والنتيجة أن تمرير Carbon يكتب
 * "2026-08-18 00:00:00" بينما تمرير نصّ يكتب "2026-08-18"، فيفشل التطابق في
 * updateOrCreate/firstOrCreate ويُخترق قيد unique على (course_circle_id, date).
 *
 * @implements CastsAttributes<Carbon|null, Carbon|string|null>
 */
class DateOnly implements CastsAttributes
{
    public function get(Model $model, string $key, mixed $value, array $attributes): ?Carbon
    {
        return $value === null ? null : Carbon::parse($value)->startOfDay();
    }

    public function set(Model $model, string $key, mixed $value, array $attributes): ?string
    {
        return $value === null ? null : Carbon::parse($value)->toDateString();
    }
}
