<?php

namespace App\Console\Commands;

use App\Actions\RecalculateCircleStats;
use App\Models\Course;
use Illuminate\Console\Command;

/**
 * إعادة بناء إحصاء الحلقات وترتيبها من سجل التفقّد.
 *
 * الحساب يجري عادةً لحظة إغلاق كل جلسة؛ هذا الأمر للحالات التي يتخلّف فيها الإحصاء:
 * بيانات مستوردة، أو تعديل رجعي واسع، أو بذر قاعدة تطوير.
 */
class RecalculateStatsCommand extends Command
{
    protected $signature = 'mousqe:recalculate-stats {--course= : معرّف الدورة، وإلا فكل الدورات الجارية}';

    protected $description = 'إعادة حساب إحصاء الحلقات اليومي والتراكمي وترتيبها في الدوام';

    public function handle(RecalculateCircleStats $recalculate): int
    {
        $courses = $this->option('course')
            ? Course::query()->whereKey($this->option('course'))->get()
            : Course::query()->where('is_current', true)->get();

        if ($courses->isEmpty()) {
            $this->components->warn('لا توجد دورة مطابقة.');

            return self::FAILURE;
        }

        foreach ($courses as $course) {
            $this->components->task(
                "إعادة حساب {$course->name}",
                fn () => $recalculate->forCourse($course->id) ?? true,
            );
        }

        return self::SUCCESS;
    }
}
