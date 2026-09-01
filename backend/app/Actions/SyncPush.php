<?php

namespace App\Actions;

use App\Enums\SyncOperation;
use App\Models\AttendanceSession;
use App\Models\ChangeLog;
use App\Models\CourseCircle;
use App\Models\Student;
use App\Models\Teacher;
use App\Models\User;
use App\Support\ApiScope;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * يطبّق دفعة عمليات أُنشئت أوف-لاين (تفقّد الأستاذ غالباً)، معتمداً على أفعال اللوحة
 * نفسها (OpenAttendanceSession/TakeAttendance/...) بدل إعادة كتابة منطقها.
 *
 * كل عملية تحمل op_uuid فريداً يولّده العميل؛ عمليةٌ سبق تطبيقها (نفس op_uuid موجود في
 * change_log) تُتجاهل بصمت فتصير إعادة الإرسال بعد انقطاع الشبكة آمنة (idempotent).
 */
class SyncPush
{
    public function __construct(
        private readonly OpenAttendanceSession $openSession,
        private readonly TakeAttendance $takeAttendance,
        private readonly TakeTeacherAttendance $takeTeacherAttendance,
        private readonly CompleteAttendanceSession $completeSession,
        private readonly SubmitAbsenceExcuse $submitExcuse,
        private readonly RecordChange $recordChange,
        private readonly ResolveAttendanceConflicts $resolveConflicts,
    ) {}

    /**
     * @param  array<int, array{op_uuid: string, type: string, course_circle_uuid?: string, session_date?: string, attendances?: array<int, array{student_uuid: string, status: string, late_minutes?: int|null, note?: string|null}>, student_uuid?: string, from_date?: string, to_date?: string, reason?: string}>  $operations
     * @return array{applied: array<int, string>, skipped: array<int, string>}
     */
    public function handle(User $user, array $operations, ?string $deviceUuid = null): array
    {
        $scope = ApiScope::for($user);
        $institute = $scope->institute();
        $scopeKey = $scope->scopeKey();

        $applied = [];
        $skipped = [];

        foreach ($operations as $op) {
            $opUuid = $op['op_uuid'];

            if (ChangeLog::query()->where('op_uuid', $opUuid)->exists()) {
                $skipped[] = $opUuid;

                continue;
            }

            DB::transaction(function () use ($op, $user, $institute, $scopeKey, $deviceUuid): void {
                $this->apply($op, $user, $institute->id, $scopeKey, $deviceUuid, $op['op_uuid']);
            });

            $applied[] = $opUuid;
        }

        return ['applied' => $applied, 'skipped' => $skipped];
    }

    /**
     * @param  array<string, mixed>  $op
     */
    private function apply(array $op, User $user, int $instituteId, string $scopeKey, ?string $deviceUuid, string $opUuid): void
    {
        match ($op['type'] ?? null) {
            'attendance.session.open' => $this->applyOpenSession($op, $user, $instituteId, $scopeKey, $deviceUuid, $opUuid),
            'attendance.take' => $this->applyTakeAttendance($op, $user, $instituteId, $scopeKey, $deviceUuid, $opUuid),
            'attendance.teacher.take' => $this->applyTakeTeacherAttendance($op, $user, $scopeKey, $deviceUuid, $opUuid),
            'attendance.session.complete' => $this->applyCompleteSession($op, $user, $scopeKey, $deviceUuid, $opUuid),
            'excuse.submit' => $this->applySubmitExcuse($op, $user, $instituteId, $scopeKey, $deviceUuid, $opUuid),
            default => throw new RuntimeException("نوع عملية غير معروف: {$op['type']}"),
        };
    }

    /**
     * @param  array<string, mixed>  $op
     */
    private function applyOpenSession(array $op, User $user, int $instituteId, string $scopeKey, ?string $deviceUuid, string $opUuid): void
    {
        $courseCircle = $this->courseCircle($op['course_circle_uuid'], $instituteId);

        $session = $this->openSession->handle($courseCircle, $op['session_date'] ?? null, $user);

        $this->recordChange->handle($session, SyncOperation::Create, $scopeKey, $user, $deviceUuid, $opUuid);
    }

    /**
     * @param  array<string, mixed>  $op
     */
    private function applyTakeAttendance(array $op, User $user, int $instituteId, string $scopeKey, ?string $deviceUuid, string $opUuid): void
    {
        $session = $this->attendanceSession($op['session_uuid'], $instituteId);

        $rows = [];

        foreach ($op['attendances'] ?? [] as $row) {
            $student = Student::where('uuid', $row['student_uuid'])->where('institute_id', $instituteId)->first();

            if ($student === null) {
                continue;
            }

            $rows[$student->id] = [
                'status' => $row['status'] ?? null,
                'late_minutes' => $row['late_minutes'] ?? null,
                'note' => $row['note'] ?? null,
                'recorded_at' => $row['recorded_at'] ?? null,
            ];
        }

        $rows = $this->resolveConflicts->handle($session, $rows, $deviceUuid);

        $session = $this->takeAttendance->handle($session, $rows, $user, (bool) ($op['amend'] ?? false));

        $this->recordChange->handle($session, SyncOperation::Update, $scopeKey, $user, $deviceUuid, $opUuid);
    }

    /**
     * @param  array<string, mixed>  $op
     */
    private function applyTakeTeacherAttendance(array $op, User $user, string $scopeKey, ?string $deviceUuid, string $opUuid): void
    {
        $session = AttendanceSession::where('uuid', $op['session_uuid'])->firstOrFail();

        $rows = [];

        foreach ($op['teacher_attendances'] ?? [] as $row) {
            $teacher = Teacher::where('uuid', $row['teacher_uuid'])->first();

            if ($teacher === null) {
                continue;
            }

            $rows[$teacher->id] = [
                'status' => $row['status'] ?? null,
                'late_minutes' => $row['late_minutes'] ?? null,
                'note' => $row['note'] ?? null,
            ];
        }

        $session = $this->takeTeacherAttendance->handle($session, $rows, $user);

        $this->recordChange->handle($session, SyncOperation::Update, $scopeKey, $user, $deviceUuid, $opUuid);
    }

    /**
     * @param  array<string, mixed>  $op
     */
    private function applyCompleteSession(array $op, User $user, string $scopeKey, ?string $deviceUuid, string $opUuid): void
    {
        $session = AttendanceSession::where('uuid', $op['session_uuid'])->firstOrFail();

        $session = $this->completeSession->handle($session, $user);

        $this->recordChange->handle($session, SyncOperation::Update, $scopeKey, $user, $deviceUuid, $opUuid);
    }

    /**
     * @param  array<string, mixed>  $op
     */
    private function applySubmitExcuse(array $op, User $user, int $instituteId, string $scopeKey, ?string $deviceUuid, string $opUuid): void
    {
        $student = Student::where('uuid', $op['student_uuid'])->where('institute_id', $instituteId)->firstOrFail();

        $excuse = $this->submitExcuse->handle($student, [
            'from_date' => $op['from_date'],
            'to_date' => $op['to_date'],
            'reason' => $op['reason'],
            'attachment_path' => $op['attachment_path'] ?? null,
        ], $user);

        $this->recordChange->handle($excuse, SyncOperation::Create, $scopeKey, $user, $deviceUuid, $opUuid);
    }

    private function courseCircle(string $uuid, int $instituteId): CourseCircle
    {
        return CourseCircle::where('uuid', $uuid)
            ->whereHas('circle', fn ($q) => $q->where('institute_id', $instituteId))
            ->firstOrFail();
    }

    private function attendanceSession(string $uuid, int $instituteId): AttendanceSession
    {
        return AttendanceSession::where('uuid', $uuid)
            ->whereHas('courseCircle.circle', fn ($q) => $q->where('institute_id', $instituteId))
            ->firstOrFail();
    }
}
