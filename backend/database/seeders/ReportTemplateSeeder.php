<?php

namespace Database\Seeders;

use App\Enums\ReportScope;
use App\Models\Institute;
use App\Models\ReportTemplate;
use Illuminate\Database\Seeder;

/**
 * قوالب التقارير الافتراضية لكل معهد — يعدّلها المشرف من /settings/report-templates.
 */
class ReportTemplateSeeder extends Seeder
{
    public function run(): void
    {
        foreach (Institute::all() as $institute) {
            foreach ($this->templates() as $template) {
                ReportTemplate::updateOrCreate(
                    ['institute_id' => $institute->id, 'key' => $template['key']],
                    [...$template, 'institute_id' => $institute->id],
                );
            }
        }
    }

    /**
     * @return array<int, array{key: string, name: string, scope: ReportScope, body: string}>
     */
    private function templates(): array
    {
        return [
            [
                'key' => 'daily_circle_summary',
                'name' => 'ملخّص الحلقة اليومي',
                'scope' => ReportScope::Circle,
                'body' => <<<'TXT'
                    {{institute_name}}
                    تقرير {{circle_name}} — {{weekday}} {{date}} ({{date_hijri}})

                    الأستاذ: {{teacher_names}}
                    الحاضرون: {{present}} · الغائبون: {{absent}} · المتأخّرون: {{late}} · المأذونون: {{excused}}
                    نسبة الحضور: {{rate}}
                    الترتيب اليومي في {{shift_name}}: {{daily_rank}}

                    الغائبون: {{absent_list}}
                    TXT,
            ],
            [
                'key' => 'guardian_absence_notice',
                'name' => 'إشعار غياب لولي الأمر',
                'scope' => ReportScope::Circle,
                'body' => <<<'TXT'
                    السلام عليكم ورحمة الله وبركاته

                    نفيدكم بأن ابنكم لم يحضر حلقة {{circle_name}} يوم {{weekday}} الموافق {{date}}.
                    نرجو إفادتنا بسبب الغياب، أو تقديم إذن مسبق عبر التطبيق.

                    {{institute_name}}
                    TXT,
            ],
            [
                'key' => 'weekly_circle_standing',
                'name' => 'مركز الحلقة التراكمي',
                'scope' => ReportScope::Shift,
                'body' => <<<'TXT'
                    {{institute_name}} — {{course_name}}
                    مركز {{circle_name}} في {{shift_name}} حتى {{date}}

                    عدد الجلسات: {{sessions_count}}
                    النسبة التراكمية: {{overall_rate}}
                    الترتيب الكلي: {{overall_rank}}
                    TXT,
            ],
        ];
    }
}
