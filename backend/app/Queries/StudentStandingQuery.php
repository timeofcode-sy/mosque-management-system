<?php

namespace App\Queries;

use App\Enums\AttendanceStatus;
use App\Models\Attendance;
use App\Models\Enrollment;
use App\Models\Student;
use App\Support\AttendanceRate;
use Illuminate\Support\Collection;

/**
 * موقعُ الطالب بين زملاء حلقته — ✅ م.8.1.
 *
 * ## 🔑 لماذا يُحسب هنا لا على الجهاز؟
 *
 * [APPS-FEATURES.md §6.2](../../../docs/APPS-FEATURES.md) البند 2 كان يقول «يُحسب
 * محلياً»، وثمنُ ذلك أن يستقبل هاتفُ الطالب **صفوفَ حضورِ كلِّ زملائه** ليستخرج
 * منها رقماً واحداً — وهو أوسعُ تسريبٍ في النظام وأقلُّه مبرِّراً: الطالبُ يقرأ
 * عن نفسه، وحاجتُه إلى غيره رقمُ رتبةٍ لا أكثر.
 *
 * فقُلب الاتجاه: الخادمُ يحسب الرتبة ويعيد **الرقمَ وحده**، ويخرج الطالبُ من
 * `sync/pull` كما خرج وليُّ الأمر في م.7.1
 * ([PHASE-8-STAGES.MD §1.1](../../../docs/PHASE-8-STAGES.MD)).
 *
 * ## والمعادلةُ واحدة
 *
 * `AttendanceRate` نفسُها التي تحسب نسبةَ اللوحة وتقريرِ الحلقة والداشبورد —
 * فرتبةُ الطالب في تطبيقه ورتبتُه في تقرير حلقته **حسابٌ واحد لا اثنان يتقاربان**.
 */
class StudentStandingQuery
{
    /**
     * @return array{circle_name: ?string, rank: ?int, peers: int, rate: ?float, points: float}
     */
    public function for(Student $student): array
    {
        $enrolment = $student->enrollments()
            ->whereNull('left_on')
            ->with('courseCircle.circle')
            ->latest('enrolled_on')
            ->first();

        if ($enrolment === null) {
            return self::unranked();
        }

        $rates = $this->ratesOfCircle($enrolment);
        $mine = $rates->get($student->id);

        // 🔑 `null` تعني «لم يُقَس» لا «الأخير» — قاعدةُ م.6.6. طالبٌ لا صفَّ حضورٍ
        // له بعد (سُجِّل اليوم، أو حلقةٌ لم تُفتح جلستُها) لا يُرتَّب ولا يُذيَّل.
        if ($mine === null) {
            return self::unranked(
                circleName: $enrolment->courseCircle?->circle?->name,
                peers: $rates->count(),
            );
        }

        return [
            'circle_name' => $enrolment->courseCircle?->circle?->name,
            // الرتبةُ عددُ من يعلوه + 1، **والتعادلُ يأخذ الرتبةَ نفسَها** — كما
            // في تقرير نقاط الحلقة (م.4.5)، فلا يفترق الرقمان.
            'rank' => $rates->filter(fn (float $rate) => $rate > $mine)->count() + 1,
            'peers' => $rates->count(),
            'rate' => $mine,
            'points' => $this->pointsOf($student),
        ];
    }

    /**
     * نسبةُ كلِّ طالبٍ مسجَّلٍ في الحلقة — **تُحسب ولا تُعاد**.
     *
     * الخرجُ من هذه الدالّة يبقى داخل الخادم: يُستعمل للمقارنة ثم يُطرح. ولا
     * يخرج منه إلى الشبكة إلا رقمُ رتبةِ صاحب الطلب وعددُ زملائه.
     *
     * @return Collection<int, float>
     */
    private function ratesOfCircle(Enrollment $enrolment): Collection
    {
        $studentIds = Enrollment::query()
            ->where('course_circle_id', $enrolment->course_circle_id)
            ->whereNull('left_on')
            ->pluck('student_id')
            ->unique();

        if ($studentIds->isEmpty()) {
            return new Collection;
        }

        return Attendance::query()
            ->whereIn('student_id', $studentIds)
            ->whereHas('attendanceSession', fn ($query) => $query
                ->where('course_circle_id', $enrolment->course_circle_id))
            ->selectRaw('student_id, status, count(*) as aggregate')
            ->groupBy('student_id', 'status')
            ->get()
            ->groupBy('student_id')
            ->map(function (Collection $rows): float {
                // `status` مصبوبٌ إلى `AttendanceStatus`، و`pluck` بمفتاحٍ enum
                // يرمي لأن مفاتيحَ المصفوفة في PHP نصوصٌ وأعدادٌ لا غير. فيُقرأ
                // `->value` صراحةً بدل الاعتماد على تحويلٍ ضمنيّ لا يقع.
                $counts = $rows->mapWithKeys(
                    fn ($row) => [$row->status->value => (int) $row->aggregate],
                );

                $present = (int) ($counts[AttendanceStatus::Present->value] ?? 0);
                $late = (int) ($counts[AttendanceStatus::Late->value] ?? 0);
                $excused = (int) ($counts[AttendanceStatus::Excused->value] ?? 0);
                $absent = (int) ($counts[AttendanceStatus::Absent->value] ?? 0);

                return AttendanceRate::percent($present, $late, $excused, $present + $late + $excused + $absent);
            });
    }

    /**
     * مجموعُ نقاطه في الدورة الجارية — من `StudentPointsQuery` القائم منذ م.4.5.
     */
    private function pointsOf(Student $student): float
    {
        $course = $student->institute?->currentCourse();

        if ($course === null) {
            return 0.0;
        }

        $totals = app(StudentPointsQuery::class)->forStudent(
            $student,
            $course->starts_on->toDateString(),
            $course->ends_on->toDateString(),
        );

        return (float) ($totals['total'] ?? 0);
    }

    /**
     * @return array{circle_name: ?string, rank: null, peers: int, rate: null, points: float}
     */
    private static function unranked(?string $circleName = null, int $peers = 0): array
    {
        return [
            'circle_name' => $circleName,
            'rank' => null,
            'peers' => $peers,
            'rate' => null,
            'points' => 0.0,
        ];
    }
}
