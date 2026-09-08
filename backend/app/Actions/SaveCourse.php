<?php

namespace App\Actions;

use App\Models\Course;
use App\Models\Institute;

/**
 * إنشاء دورة أو تحريرها.
 *
 * كانت الشاشةُ تكتب `Course::updateOrCreate` مباشرةً، فلمّا احتاجها الديسكتوب
 * (م.6.2) لم يكن ثمّة ما يُستدعى. أُخرجت الكتابةُ إلى فعلٍ مشترك — نفسُ قاعدة
 * [ARCHITECTURE.md §3]: منطقُ الكتابة لا يُكتب مرّتين لسطحين.
 *
 * ولا تُبدَّل «الدورة الجارية» من هنا: ذلك قرارٌ مستقلّ في ActivateCourse لأنه
 * يمسّ كلَّ شاشةٍ تشغيلية في المعهد.
 */
class SaveCourse
{
    /**
     * @param  array<string, mixed>  $attributes  name · starts_on · ends_on? · status · notes?
     */
    public function handle(Institute $institute, array $attributes, ?Course $course = null): Course
    {
        $course ??= new Course;

        $course->fill([...$attributes, 'institute_id' => $institute->id])->save();

        return $course->refresh();
    }
}
