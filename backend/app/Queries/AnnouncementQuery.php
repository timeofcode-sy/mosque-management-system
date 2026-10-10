<?php

namespace App\Queries;

use App\Models\Announcement;
use App\Models\Enrollment;
use App\Models\Guardian;
use App\Models\Institute;
use App\Models\Student;
use App\Models\Teacher;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Collection as SupportCollection;

/**
 * الإعلاناتُ المنشورة — ✅ م.8.1.
 *
 * 🔴 **الجدولُ قائمٌ منذ م.1 وكان حمولةً ميتة**: مهاجَرٌ بـ`scope` و`scope_ids`،
 * ونموذجُه ينفّذ `Syncable`، والصلاحيتان `announcements.view` و`.manage` في
 * الكتالوج — **ولا شاشةَ تكتب ولا نقطةَ تقرأ**. وتوصيفُ
 * [APPS-FEATURES.md §6.2](../../../docs/APPS-FEATURES.md) أنه «لا جدولَ لها» كان
 * خطأً في الوثيقة لا نقصاً في المخطط.
 *
 * فبُني طرفاه معاً في هذه المرحلة، وإلا لَصار شاشةَ عرضٍ بلا كاتب — **وعدٌ لا
 * يُنجَز** ([PHASE-8-STAGES.MD §1.3](../../../docs/PHASE-8-STAGES.MD)).
 */
class AnnouncementQuery
{
    /**
     * ما يقرؤه هذا الطالب: إعلانُ معهده وإعلانُ حلقته الموجَّهان إلى «الطلاب».
     *
     * 🔑 **والترشيحُ في الخادم لا في العميل**: إعلانٌ وُجِّه إلى حلقةٍ ليست له لا
     * يصل جهازَه أصلاً، فلا يعرف بوجوده. وهو نفسُ مبدأ هذه المرحلة كلِّها — ما
     * يصله ما يخصّه لا ما يُرشَّح عنده.
     *
     * @return Collection<int, Announcement>
     */
    public function forStudent(Student $student, int $limit = 30): Collection
    {
        $circleIds = $student->enrollments()
            ->whereNull('left_on')
            ->pluck('course_circle_id');

        return $this->forAudience($student->institute, 'students', $circleIds, $limit);
    }

    /**
     * ما يقرؤه وليُّ الأمر: إعلاناتُ المعهد الموجَّهة إلى «أولياء الأمور»، وإعلاناتُ **حلقات أبنائه** (من تسجيلاتهم
     * القائمة) الموجَّهة إليهم. وليٌّ بلا ابنٍ مسجَّل في حلقة لا يرى إلا الشاملَ للمعهد.
     *
     * @return Collection<int, Announcement>
     */
    public function forGuardian(Guardian $guardian, int $limit = 30): Collection
    {
        $circleIds = Enrollment::query()
            ->whereNull('left_on')
            ->whereIn('student_id', $guardian->students()->pluck('students.id'))
            ->pluck('course_circle_id');

        return $this->forAudience($guardian->institute, 'guardians', $circleIds, $limit);
    }

    /**
     * ما يقرؤه الأستاذ: الإعلاناتُ الموجَّهة إلى «الأساتذة» للمعهد كلِّه أو لحلقاتٍ **أُسندت إليه**.
     *
     * @return Collection<int, Announcement>
     */
    public function forTeacher(Teacher $teacher, int $limit = 30): Collection
    {
        $circleIds = $teacher->courseCircles()->pluck('course_circles.id');

        return $this->forAudience($teacher->institute, 'teachers', $circleIds, $limit);
    }

    /**
     * الإعلاناتُ المنشورة لفئةٍ في معهد: ما كان `scope = all`، وما وُجِّه إلى إحدى [$circleIds].
     *
     * @param  SupportCollection<int, int|string|null>  $circleIds
     * @return Collection<int, Announcement>
     */
    private function forAudience(?Institute $institute, string $audience, SupportCollection $circleIds, int $limit): Collection
    {
        $circleIds = $circleIds->filter()->map(fn ($id) => (int) $id)->unique()->values();

        return $this->published($institute)
            // الفئة: العمودُ json؛ والإعلاناتُ القديمة بلا فئةٍ (null) كانت للطلاب فقط.
            ->where(function ($query) use ($audience) {
                $query->whereJsonContains('audience', $audience);

                if ($audience === 'students') {
                    $query->orWhereNull('audience');
                }
            })
            ->where(function ($query) use ($circleIds) {
                $query->where('scope', 'all');

                // حلقةٌ واحدة على الأقل: `scope_ids` عمودُ json، والمقارنةُ
                // بـ`whereJsonContains` تعمل على SQLite وMySQL معاً.
                foreach ($circleIds as $circleId) {
                    $query->orWhere(fn ($inner) => $inner
                        ->where('scope', 'circle')
                        ->whereJsonContains('scope_ids', $circleId));
                }
            })
            ->limit($limit)
            ->get();
    }

    /**
     * إعلاناتُ المعهد كلُّها لِمن يديرها — تُستهلَك من شاشة اللوحة.
     *
     * @return Collection<int, Announcement>
     */
    public function forInstitute(?Institute $institute, int $limit = 100): Collection
    {
        if ($institute === null) {
            return new Collection;
        }

        return Announcement::query()
            ->where('institute_id', $institute->id)
            ->with('createdBy')
            ->latest('created_at')
            ->limit($limit)
            ->get();
    }

    /**
     * المنشورُ وحده: **المسودّةُ ليست إعلاناً**.
     *
     * `published_at` فارغةٌ ⇒ كُتب ولم يُنشَر بعد، وتاريخٌ في المستقبل ⇒ مجدوَلٌ
     * لم يحن وقتُه. وكلاهما لا يصل قارئاً.
     *
     * @return Builder<Announcement>
     */
    private function published(?Institute $institute): Builder
    {
        return Announcement::query()
            ->where('institute_id', $institute?->id)
            ->whereNotNull('published_at')
            ->where('published_at', '<=', now())
            ->latest('published_at');
    }
}
