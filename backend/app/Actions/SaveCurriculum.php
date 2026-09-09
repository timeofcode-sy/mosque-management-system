<?php

namespace App\Actions;

use App\Models\Curriculum;
use App\Models\Institute;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * إنشاء منهج أو تحريره.
 *
 * أُخرج من شاشة المناهج في م.6.5 ليستدعيه السطحان — نفسُ ما وقع لـ`SaveCourse`
 * و`SaveShift` و`SaveCircle` في م.6.2 ([ARCHITECTURE.md §3]): منطقُ الكتابة لا
 * يُكتب مرّتين لسطحين. و`SaveCurriculumItem` كان مُخرَجاً منذ م.4.5، فبقي
 * **الوعاءُ** وحدَه مكتوباً داخل الشاشة.
 *
 * و`slug` يُشتقّ هنا لا في الواجهة: هو عمودُ مخططٍ لا حقلُ استمارة، ولا يعرف
 * صاحبُ الشاشة أنه موجود أصلاً.
 */
class SaveCurriculum
{
    /**
     * @param  array<string, mixed>  $attributes  name · type · description? · sort_order? · is_active?
     */
    public function handle(Institute $institute, array $attributes, ?Curriculum $curriculum = null): Curriculum
    {
        $this->assertOwned($curriculum);

        $curriculum ??= new Curriculum;

        $curriculum->fill([
            ...$attributes,
            'institute_id' => $institute->id,
            'slug' => Str::slug((string) ($attributes['name'] ?? $curriculum->name)) ?: Str::random(8),
        ])->save();

        return $curriculum->refresh();
    }

    /**
     * 🔴 **منهجٌ عامّ لا يُحرَّر من معهد** — عطبٌ كشفته م.6.5.
     *
     * المناهجُ المزروعة (`institute_id = null`) يراها كلُّ معهد
     * (`InstituteCatalogQuery::curricula` = «العامّ أو معهدي»)، وكان الحفظُ يُسند
     * `institute_id` بلا شرط. فتعديلُ اسم «القرآن الكريم» من معهدٍ واحد كان
     * **ينقله إلى ملكِه** فيختفي — بأجزائه الثلاثين وسجلّاتِ التقدّم المعلّقة
     * عليها — عن كلِّ معهدٍ آخر في النظام. وهو صمتٌ لا عطبٌ ظاهر: لا خطأ يُرمى،
     * والمعهدُ الآخر يفتح شاشتَه فلا يجد منهجاً.
     *
     * والحكمُ في الفعل لا في المتحكّم، فيسري على اللوحة كما على الديسكتوب.
     */
    private function assertOwned(?Curriculum $curriculum): void
    {
        if ($curriculum !== null && $curriculum->institute_id === null) {
            throw new RuntimeException('المناهج العامة لا تُحرَّر من داخل معهد — أضِف منهجاً خاصاً بالمعهد بدلاً منها.');
        }
    }
}
