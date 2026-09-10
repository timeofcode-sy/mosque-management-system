<?php

namespace App\Queries;

use App\Models\AbsenceExcuse;
use App\Models\Guardian;
use App\Models\Student;
use Illuminate\Support\Collection;

/**
 * أبناء ولي الأمر وما يقرؤه عنهم — أساس تطبيق الأهل (المرحلة 7).
 *
 * 🔑 **الحصرُ ههنا لا في الشاشة ولا في المتحكّم**: كلُّ قراءةٍ في هذا الصنف تبدأ
 * من `guardian->students()`، فابنُ غيرِه لا يدخل النتيجةَ أصلاً بدل أن يدخلها ثم
 * يُحجب. وطلبُ ابنٍ ليس له ⇒ 404 لا 403 — لأن 403 يؤكّد وجودَ الطالب
 * ([API.md §4](../../../docs/API.md)).
 */
class GuardianChildrenQuery
{
    /**
     * @return Collection<int, Student>
     */
    public function children(Guardian $guardian): Collection
    {
        return $guardian->students()->get();
    }

    /**
     * ابنٌ بعينه من أبناء هذا الوليّ — أو استثناءُ 404.
     *
     * البابُ **الوحيد** الذي تدخل منه النقاطُ الثلاثُ التي تأخذ معرّفَ ابن،
     * فلا تجتهد كلُّ واحدةٍ منها بحصرِها.
     */
    public function child(Guardian $guardian, string $studentUuid): Student
    {
        return $guardian->students()->where('students.uuid', $studentUuid)->firstOrFail();
    }

    /**
     * الأعذارُ التي قدّمها هذا الوليّ عن أبنائه، الأحدثُ أوّلاً.
     *
     * ✅ م.7.1 — نتيجةُ خروج وليّ الأمر من `sync/pull` (القرار 0.1 في
     * [PHASE-7-STAGES.MD](../../../docs/PHASE-7-STAGES.MD)): بلا هذه القراءة يقدّم
     * إذناً ثم لا يرى جوابَ الطاقم عليه أبداً.
     *
     * **والنطاقُ أبناؤه لا ما قدّمه هو**: المشرفُ يقدّم الإذنَ نيابةً عنه حين يصل
     * هاتفياً (`SubmitAbsenceExcuse` يُستدعى من اللوحة أيضاً)، وذاك إذنٌ عن ابنه
     * يحقّ له أن يتابعه ولو لم يكن هو مَن كتبه.
     *
     * @return Collection<int, AbsenceExcuse>
     */
    public function excuses(Guardian $guardian, int $limit = 50): Collection
    {
        // معرّفاتُ الأبناء تُقرأ صراحةً لا تُمرَّر علاقةً داخل whereIn: العلاقةُ
        // BelongsToMany لا Builder، وتمريرُها يعتمد على تمريرِ نداءٍ لا يضمنه عقد.
        // ولوليّ الأمر أبناءٌ معدودون، فالاستعلامُ الثاني بلا ثمن.
        $childIds = $guardian->students()->pluck('students.id');

        return AbsenceExcuse::query()
            ->whereIn('student_id', $childIds)
            ->with('student')
            ->latest('created_at')
            ->limit($limit)
            ->get();
    }
}
