<?php

namespace App\Actions;

use App\Enums\SyncOperation;
use App\Models\AttendanceSession;
use App\Models\ChangeLog;
use App\Models\CourseCircle;
use App\Models\MemorizationLog;
use App\Models\Student;
use App\Models\StudentPoint;
use App\Models\SyncDevice;
use App\Models\Teacher;
use App\Models\User;
use App\Support\ApiScope;
use App\Support\SyncRecorder;
use App\Support\SyncScope;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Support\Facades\DB;
use RuntimeException;
use Throwable;

/**
 * يطبّق دفعة عمليات أُنشئت أوف-لاين (تفقّد الأستاذ غالباً)، معتمداً على أفعال اللوحة
 * نفسها (OpenAttendanceSession/TakeAttendance/...) بدل إعادة كتابة منطقها.
 *
 * كل عملية تحمل op_uuid فريداً يولّده العميل؛ عمليةٌ سبق تطبيقها (نفس op_uuid موجود في
 * change_log) تُتجاهل بصمت فتصير إعادة الإرسال بعد انقطاع الشبكة آمنة (idempotent).
 *
 * 🔄 م.6.1 — **العملية المسمومة لم تعد توقف الطابور كلَّه.** كانت الدفعة كتلةً واحدة:
 * عمليةٌ ترفع استثناءً تُنهي الطلب كلَّه، فتبقى العشرُ اللاحقة معلّقةً في الجهاز إلى
 * الأبد لأن الأولى لن تنجح أبداً — وهو خطرٌ ازداد بالديسكتوب: جهازٌ ثانٍ يكتب بالتوازي
 * فيَكثُر ما يُرفض. صارت كلُّ عملية في معاملتها، والمرفوضةُ تُردّ في failed[] برسالتها
 * ويمضي الباقي. والحكمُ فيها لصاحب الجهاز: العميل يعزلها ويعرضها ولا يحذفها
 * ([SYNC-PROTOCOL.md §3]).
 *
 * 🔄 تسجيلُ التغيير لم يعد من مسؤولية هذا الصنف: مراقب App\Concerns\RecordsSyncChanges
 * يسجّل **كلّ صفٍّ تغيّر فعلاً** لا صفَّ الجلسة وحده — وكان الأوّلُ ينقص العميلَ صفوفَ
 * الحضور نفسها. ما بقي هنا ضبطُ السياق (المستخدم والجهاز وop_uuid) وصفٌّ دالٌّ للعملية
 * التي لم تغيّر شيئاً، حفظاً لمنع التكرار.
 */
class SyncPush
{
    public function __construct(
        private readonly OpenAttendanceSession $openSession,
        private readonly TakeAttendance $takeAttendance,
        private readonly TakeTeacherAttendance $takeTeacherAttendance,
        private readonly CompleteAttendanceSession $completeSession,
        private readonly SubmitAbsenceExcuse $submitExcuse,
        private readonly SaveRecitation $saveRecitation,
        private readonly DeleteRecitation $deleteRecitation,
        private readonly AwardStudentPoints $awardPoints,
        private readonly DeleteStudentPoints $deletePoints,
        private readonly RecordChange $recordChange,
        private readonly ResolveAttendanceConflicts $resolveConflicts,
        private readonly SyncRecorder $recorder,
    ) {}

    /**
     * @param  array<int, array{op_uuid: string, type: string, course_circle_uuid?: string, session_date?: string, attendances?: array<int, array{student_uuid: string, status: string, late_minutes?: int|null, note?: string|null}>, student_uuid?: string, from_date?: string, to_date?: string, reason?: string}>  $operations
     * @return array{applied: array<int, string>, skipped: array<int, string>, failed: array<int, array{op_uuid: string, message: string}>}
     */
    public function handle(User $user, array $operations, ?string $deviceUuid = null): array
    {
        $scope = ApiScope::for($user);
        $institute = $scope->institute();
        $scopeKey = $scope->scopeKey();

        $applied = [];
        $skipped = [];
        $failed = [];

        foreach ($operations as $op) {
            $opUuid = $op['op_uuid'];

            if (ChangeLog::query()->where('op_uuid', $opUuid)->exists()) {
                $skipped[] = $opUuid;

                continue;
            }

            try {
                DB::transaction(function () use ($op, $user, $institute, $scopeKey, $deviceUuid, $opUuid): void {
                    $target = null;

                    $recorded = $this->recorder->during($user, $deviceUuid, $opUuid, function () use (&$target, $op, $user, $institute, $deviceUuid): void {
                        $target = $this->apply($op, $user, $institute->id, $deviceUuid);
                    });

                    // صفٌّ دالّ لعمليةٍ لم تغيّر شيئاً — إلا حين لا يوجد صفّ أصلاً (حذفُ
                    // ما سبق حذفُه): تلك تُعدّ مطبَّقة فيُنظَّف الطابور، بلا صفٍّ تسجّله.
                    if (! $recorded && $target !== null) {
                        $this->recordChange->handle($target, SyncOperation::Update, $scopeKey, $user, $deviceUuid, $opUuid);
                    }
                });
            } catch (Throwable $exception) {
                $failed[] = ['op_uuid' => $opUuid, 'message' => self::reason($exception)];

                continue;
            }

            $applied[] = $opUuid;
        }

        $this->touchDevice($deviceUuid);

        return ['applied' => $applied, 'skipped' => $skipped, 'failed' => $failed];
    }

    /**
     * سببُ الرفض بالعربية — يعرضه العميل لصاحب الجهاز.
     *
     * رسالةُ ModelNotFoundException اسمُ صنفٍ ومعرّف، وهي لغةُ سجلٍّ لا لغةُ مستخدم؛
     * وما عداها رسائلُ أفعالنا نفسها («الجلسة مقفلة…») وهي مكتوبةٌ للقراءة أصلاً.
     */
    private static function reason(Throwable $exception): string
    {
        if ($exception instanceof ModelNotFoundException) {
            return 'صفٌّ تقصده العملية غير موجود في هذا المعهد.';
        }

        return $exception->getMessage();
    }

    /**
     * الصفّ الذي مسّته العملية — يُستعمل صفّاً دالاً حين لا تغيّر العملية شيئاً،
     * و`null` حين لا صفَّ لها أصلاً (حذفُ ما سبق حذفُه).
     *
     * @param  array<string, mixed>  $op
     */
    private function apply(array $op, User $user, int $instituteId, ?string $deviceUuid): ?Model
    {
        return match ($op['type'] ?? null) {
            'attendance.session.open' => $this->applyOpenSession($op, $user, $instituteId),
            'attendance.take' => $this->applyTakeAttendance($op, $user, $instituteId, $deviceUuid),
            'attendance.teacher.take' => $this->applyTakeTeacherAttendance($op, $user, $instituteId),
            'attendance.session.complete' => $this->applyCompleteSession($op, $user, $instituteId),
            'excuse.submit' => $this->applySubmitExcuse($op, $user, $instituteId),
            'recitation.save' => $this->applySaveRecitation($op, $user, $instituteId),
            'recitation.delete' => $this->applyDeleteRecitation($op, $instituteId),
            'points.award' => $this->applyAwardPoints($op, $user, $instituteId),
            'points.delete' => $this->applyDeletePoints($op, $instituteId),
            default => throw new RuntimeException("نوع عملية غير معروف: {$op['type']}"),
        };
    }

    /**
     * @param  array<string, mixed>  $op
     */
    private function applyOpenSession(array $op, User $user, int $instituteId): AttendanceSession
    {
        $courseCircle = $this->courseCircle($op['course_circle_uuid'], $instituteId);

        return $this->openSession->handle($courseCircle, $op['session_date'] ?? null, $user, $op['uuid'] ?? null);
    }

    /**
     * @param  array<string, mixed>  $op
     */
    private function applyTakeAttendance(array $op, User $user, int $instituteId, ?string $deviceUuid): AttendanceSession
    {
        $session = $this->attendanceSession($op, $instituteId);

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

        return $this->takeAttendance->handle($session, $rows, $user, (bool) ($op['amend'] ?? false));
    }

    /**
     * @param  array<string, mixed>  $op
     */
    private function applyTakeTeacherAttendance(array $op, User $user, int $instituteId): AttendanceSession
    {
        $session = $this->attendanceSession($op, $instituteId);

        $rows = [];

        foreach ($op['teacher_attendances'] ?? [] as $row) {
            $teacher = Teacher::where('uuid', $row['teacher_uuid'])->where('institute_id', $instituteId)->first();

            if ($teacher === null) {
                continue;
            }

            $rows[$teacher->id] = [
                'status' => $row['status'] ?? null,
                'late_minutes' => $row['late_minutes'] ?? null,
                'note' => $row['note'] ?? null,
            ];
        }

        return $this->takeTeacherAttendance->handle($session, $rows, $user);
    }

    /**
     * @param  array<string, mixed>  $op
     */
    private function applyCompleteSession(array $op, User $user, int $instituteId): AttendanceSession
    {
        return $this->completeSession->handle($this->attendanceSession($op, $instituteId), $user);
    }

    /**
     * @param  array<string, mixed>  $op
     */
    private function applySubmitExcuse(array $op, User $user, int $instituteId): Model
    {
        $student = $this->student($op['student_uuid'], $instituteId);

        return $this->submitExcuse->handle($student, [
            'from_date' => $op['from_date'],
            'to_date' => $op['to_date'],
            'reason' => $op['reason'],
            'attachment_path' => $op['attachment_path'] ?? null,
        ], $user);
    }

    /**
     * @param  array<string, mixed>  $op
     */
    private function applySaveRecitation(array $op, User $user, int $instituteId): Model
    {
        $session = $this->attendanceSession($op, $instituteId);
        $student = $this->student($op['student_uuid'], $instituteId);

        return $this->saveRecitation->handle($session, $student, $op['recitation'] ?? [], $user, $op['recorded_at'] ?? null);
    }

    /**
     * @param  array<string, mixed>  $op
     */
    private function applyDeleteRecitation(array $op, int $instituteId): ?MemorizationLog
    {
        $log = $this->deletable(MemorizationLog::query(), $op['recitation_uuid'], $instituteId);

        if ($log === null) {
            return null;
        }

        $this->deleteRecitation->handle($log);

        return $log;
    }

    /**
     * @param  array<string, mixed>  $op
     */
    private function applyDeletePoints(array $op, int $instituteId): ?StudentPoint
    {
        $award = $this->deletable(StudentPoint::query(), $op['point_uuid'], $instituteId);

        if ($award === null) {
            return null;
        }

        $this->deletePoints->handle($award);

        return $award;
    }

    /**
     * الصفّ المقصود بالحذف، أو `null` إن لم يعد له وجود — و404 إن كان لمعهد آخر.
     *
     * 🔄 م.5.4: الحالتان تبدوان واحدة («لم يُعثر عليه») وهما نقيضان. حذفُ ما لا وجود
     * له **نتيجةٌ محقَّقة**: العميلُ قد يصفّ الحذف مرّتين، أو يحذف ما حذفه غيرُه، ولو
     * رُدّ بـ404 لَعلق الطابورُ كلُّه خلف عمليةٍ لن تنجح أبداً. أمّا معرّفٌ من معهدٍ آخر
     * فمحاولةُ عبور حاجز المعهد، وردُّها 404 كما كان.
     *
     * @param  Builder<TModel>  $query
     * @return TModel|null
     *
     * @template TModel of Model
     */
    private function deletable($query, string $uuid, int $instituteId): ?Model
    {
        $row = $query->where('uuid', $uuid)->first();

        if ($row === null) {
            return null;
        }

        if (SyncScope::via(Student::class, $row->student_id) !== $instituteId) {
            throw (new ModelNotFoundException)->setModel($row::class, [$uuid]);
        }

        return $row;
    }

    /**
     * @param  array<string, mixed>  $op
     */
    private function applyAwardPoints(array $op, User $user, int $instituteId): Model
    {
        $student = $this->student($op['student_uuid'], $instituteId);

        $session = blank($op['session_uuid'] ?? null) && blank($op['course_circle_uuid'] ?? null)
            ? null
            : $this->attendanceSession($op, $instituteId);

        return $this->awardPoints->handle($student, [
            'uuid' => $op['uuid'] ?? null,
            'points' => $op['points'],
            'reason' => $op['reason'],
            'note' => $op['note'] ?? null,
            'awarded_on' => $op['awarded_on'] ?? null,
        ], $user, $session);
    }

    /**
     * مؤشّر آخر دفعٍ للجهاز — تعرضه شاشة system/devices، وبه يُعرف الجهاز الذي توقّف
     * عن الدفع من الذي لم يُنشئ شيئاً بعد.
     */
    private function touchDevice(?string $deviceUuid): void
    {
        if ($deviceUuid === null) {
            return;
        }

        SyncDevice::query()->where('device_uuid', $deviceUuid)->update(['last_pushed_at' => now()]);
    }

    private function student(string $uuid, int $instituteId): Student
    {
        return Student::where('uuid', $uuid)->where('institute_id', $instituteId)->firstOrFail();
    }

    private function courseCircle(string $uuid, int $instituteId): CourseCircle
    {
        return CourseCircle::where('uuid', $uuid)
            ->whereHas('circle', fn ($q) => $q->where('institute_id', $instituteId))
            ->firstOrFail();
    }

    /**
     * الجلسة التي تقصدها العملية — بمعرّفها، أو بمفتاحها الطبيعي حين لا يُطابق المعرّف.
     *
     * 🔄 م.5.3: العميلُ الذي يفتح جلسةً أوف-لاين يولّد لها uuid ويرسله في
     * attendance.session.open، فتُنشأ به على الخادم ويطابق ما في الطابور. لكن جهازين
     * فتحا نفس الجلسة أوف-لاين — أو مشرفاً سبقهما من اللوحة — يعني أن الصفّ القائم
     * يحمل معرّفاً آخر، والمفتاح الطبيعي (course_circle_id, session_date) هو **الوحيد**
     * الذي يتفق عليه الجميع (وهو قيد unique في الهجرة). فلذلك تُرسَل
     * course_circle_uuid وsession_date مع كل عملية جلسة أُنشئت أوف-لاين، وتُستعمل
     * احتياطاً هنا — وإلا ضاع تفقّدُ يومٍ كاملٍ بـ404 لأن جهازاً آخر سبقه بثانية.
     *
     * @param  array<string, mixed>  $op
     */
    private function attendanceSession(array $op, int $instituteId): AttendanceSession
    {
        $inInstitute = fn () => AttendanceSession::query()
            ->whereHas('courseCircle.circle', fn ($q) => $q->where('institute_id', $instituteId));

        if (filled($op['session_uuid'] ?? null)) {
            $session = $inInstitute()->where('uuid', $op['session_uuid'])->first();

            if ($session !== null) {
                return $session;
            }
        }

        if (filled($op['course_circle_uuid'] ?? null) && filled($op['session_date'] ?? null)) {
            $courseCircle = $this->courseCircle($op['course_circle_uuid'], $instituteId);

            $session = $inInstitute()
                ->where('course_circle_id', $courseCircle->id)
                ->whereDate('session_date', $op['session_date'])
                ->first();

            if ($session !== null) {
                return $session;
            }
        }

        throw (new ModelNotFoundException)->setModel(AttendanceSession::class, [$op['session_uuid'] ?? null]);
    }
}
