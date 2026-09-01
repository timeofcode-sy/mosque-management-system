<?php

namespace App\Actions;

use App\Models\ReportTemplate;

/**
 * استبدال متغيّرات قالب التقرير بقيمها.
 *
 * الاستبدال نصّيّ محض بلا تنفيذ Blade: القوالب يحرّرها المشرف من اللوحة،
 * وتشغيلها كقوالب Blade يفتح باب تنفيذ PHP من حقل نصّي.
 */
class RenderReportTemplate
{
    /**
     * المتغيّرات المتاحة للمشرف، معروضةً في شاشة القوالب.
     *
     * @var array<string, string>
     */
    public const VARIABLES = [
        'institute_name' => 'اسم المعهد',
        'course_name' => 'اسم الدورة',
        'circle_name' => 'اسم الحلقة',
        'shift_name' => 'اسم الدوام',
        'room' => 'القاعة',
        'teacher_names' => 'الأساتذة',
        'date' => 'التاريخ الميلادي',
        'date_hijri' => 'التاريخ الهجري',
        'weekday' => 'اليوم',
        'present' => 'عدد الحاضرين',
        'absent' => 'عدد الغائبين',
        'late' => 'عدد المتأخّرين',
        'excused' => 'عدد المأذونين',
        'total' => 'مجموع الطلاب',
        'rate' => 'نسبة حضور اليوم',
        'daily_rank' => 'الترتيب اليومي في الدوام',
        'overall_rank' => 'الترتيب الكلي في الدوام',
        'sessions_count' => 'عدد الجلسات منذ بداية الدورة',
        'overall_rate' => 'النسبة التراكمية',
        'present_list' => 'أسماء الحاضرين',
        'absent_list' => 'أسماء الغائبين',
        'late_list' => 'أسماء المتأخّرين',
        'excused_list' => 'أسماء المأذونين',
    ];

    /**
     * @param  array<string, string>  $variables
     */
    public function handle(ReportTemplate $template, array $variables): string
    {
        return $this->render($template->body, $variables);
    }

    /**
     * @param  array<string, string>  $variables
     */
    public function render(string $body, array $variables): string
    {
        return preg_replace_callback(
            '/\{\{\s*([a-z_]+)\s*\}\}/',
            fn (array $matches): string => $variables[$matches[1]] ?? $matches[0],
            $body,
        ) ?? $body;
    }
}
