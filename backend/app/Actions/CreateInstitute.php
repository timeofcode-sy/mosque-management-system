<?php

namespace App\Actions;

use App\Enums\CourseStatus;
use App\Models\Course;
use App\Models\Institute;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * إنشاء معهد جديد ومعه ما لا تعمل اللوحة بدونه.
 *
 * الدورة الأولى ليست ترفاً: كل الشاشات التشغيلية مشتقّة من currentCourse، والمعهد
 * الفارغ يستقبل صاحبه بست شاشات تقول «لا توجد دورة جارية». تُنشأ مسودّةً لا جاريةً
 * فالتواريخ والدوامات قرار صاحب المعهد.
 *
 * المناهج العامة (institute_id IS NULL) والصفات الافتراضية متاحة تلقائياً بحكم
 * استعلاماتها — لا بذر مطلوب لها.
 */
class CreateInstitute
{
    /**
     * @param  array<string, mixed>  $attributes
     */
    public function handle(array $attributes): Institute
    {
        return DB::transaction(function () use ($attributes): Institute {
            $institute = Institute::create($attributes);

            Course::create([
                'institute_id' => $institute->id,
                'name' => 'دورة '.Carbon::today()->year,
                'starts_on' => Carbon::today()->toDateString(),
                'ends_on' => Carbon::today()->addMonths(3)->toDateString(),
                'status' => CourseStatus::Draft,
                'is_current' => false,
            ]);

            return $institute;
        });
    }
}
