<?php

namespace App\Http\Controllers;

use App\Actions\BuildCircleDailyReport;
use App\Actions\BuildCirclePointsReport;
use App\Actions\BuildStudentProgressMap;
use App\Models\CourseCircle;
use App\Models\Shift;
use App\Models\Student;
use App\Queries\CircleRankingQuery;
use App\Queries\StudentProfileQuery;
use App\Support\DateRange;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\View\View;

/**
 * صفحات التقارير المهيّأة للطباعة.
 *
 * هذه استجابات HTTP عادية لا مكوّنات Livewire — لا حالة ولا تفاعل، فقط صفحة تُطبع
 * أو تُحوَّل PDF. ولهذا هي المتحكّم الوحيد في المشروع: كل ما عداها شاشات تفاعلية
 * يكون فيها مكوّن Livewire هو المتحكّم بطبعه.
 */
class ReportPrintController extends Controller
{
    public function circleDaily(Request $request, CourseCircle $courseCircle, BuildCircleDailyReport $report): View
    {
        $date = $this->date($request);

        return view('reports.circle-daily', [
            'date' => $date,
            ...$report->handle($courseCircle, $date),
        ]);
    }

    public function circlePoints(Request $request, CourseCircle $courseCircle, BuildCirclePointsReport $report): View
    {
        $range = DateRange::make(
            $request->string('range')->toString() ?: DateRange::WEEK,
            $courseCircle->course,
            $request->string('from')->toString() ?: null,
            $request->string('to')->toString() ?: null,
        );

        return view('reports.circle-points', $report->handle($courseCircle, $range));
    }

    public function shiftRanking(Request $request, Shift $shift, CircleRankingQuery $ranking): View
    {
        $date = $this->date($request);
        $mode = $request->string('mode')->toString() === 'cumulative' ? 'cumulative' : 'daily';

        return view('reports.shift-ranking', [
            'shift' => $shift->load('course.institute', 'days'),
            'date' => $date,
            'mode' => $mode,
            'rows' => $mode === 'cumulative'
                ? $ranking->cumulative($shift, $date)
                : $ranking->daily($shift, $date),
        ]);
    }

    public function student(Student $student, StudentProfileQuery $profile, BuildStudentProgressMap $progress): View
    {
        return view('reports.student', [
            'student' => $student->load('institute', 'guardians'),
            'summary' => $profile->attendanceSummary($student),
            'enrollments' => $profile->enrollments($student),
            'progressByCurriculum' => $profile->progressByCurriculum($student),
            'map' => $progress->handle($student),
        ]);
    }

    private function date(Request $request): string
    {
        $date = $request->string('date')->toString();

        return $date !== '' ? Carbon::parse($date)->toDateString() : Carbon::today()->toDateString();
    }
}
