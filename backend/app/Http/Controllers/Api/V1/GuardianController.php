<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\SubmitAbsenceExcuse;
use App\Http\Controllers\Controller;
use App\Http\Resources\V1\AttendanceResource;
use App\Http\Resources\V1\StudentResource;
use App\Models\Guardian;
use App\Queries\GuardianChildrenQuery;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class GuardianController extends Controller
{
    public function children(Request $request, GuardianChildrenQuery $query): JsonResponse
    {
        return response()->json([
            'data' => StudentResource::collection($query->children($this->guardian($request))),
        ]);
    }

    public function childAttendance(Request $request, string $student, GuardianChildrenQuery $query): JsonResponse
    {
        $guardian = $this->guardian($request);
        $child = $guardian->students()->where('students.uuid', $student)->firstOrFail();

        return response()->json([
            'data' => AttendanceResource::collection($query->attendanceOf($child)),
        ]);
    }

    public function submitExcuse(Request $request, SubmitAbsenceExcuse $action): JsonResponse
    {
        $guardian = $this->guardian($request);

        $validated = $request->validate([
            'student_uuid' => ['required', 'uuid'],
            'from_date' => ['required', 'date'],
            'to_date' => ['required', 'date', 'after_or_equal:from_date'],
            'reason' => ['required', 'string', 'max:500'],
        ]);

        $student = $guardian->students()->where('students.uuid', $validated['student_uuid'])->firstOrFail();

        $excuse = $action->handle($student, $validated, $request->user());

        return response()->json(['uuid' => $excuse->uuid, 'status' => $excuse->status], 201);
    }

    private function guardian(Request $request): Guardian
    {
        $guardian = $request->user()->guardian;

        if ($guardian === null) {
            throw new NotFoundHttpException('هذا الحساب ليس حساب ولي أمر.');
        }

        return $guardian;
    }
}
