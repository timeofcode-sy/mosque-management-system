<?php

namespace App\Actions;

use App\Enums\MemorizationType;
use App\Enums\RecitationGrade;
use App\Enums\SessionStatus;
use App\Models\AttendanceSession;
use App\Models\MemorizationLog;
use App\Models\Student;
use App\Models\User;
use App\Support\PointsSettings;
use App\Support\Quran;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * تسجيل تسميع طالب داخل جلسة.
 *
 * الأسطر والنقاط تُحسب هنا وتُجمَّد في السجلّ: النقاط للأسطر الجديدة وحدها دون المكرّر
 * (قرار المستخدم)، ومعامل التقدير يضربها. تغيير إعدادات النقاط لاحقاً لا يمسّ ما مضى.
 */
class SaveRecitation
{
    public function __construct(private readonly BuildStudentCoverageMap $coverageMap) {}

    /**
     * @param  array{uuid?: string|null, from_surah: int|string, from_ayah: int|string, to_surah: int|string, to_ayah: int|string, grade?: string|null, juz?: int|string|null, type?: string|null, curriculum_item_id?: int|null, notes?: string|null}  $data
     * @param  string|null  $recordedAt  زمن الحدث كما وقع على الجهاز — يمرّره الدفع أوف-لاين
     * @param  int|null  $editingId  سجلّ تُصحّحه اللوحة بمفتاحه الأساسي
     */
    public function handle(
        AttendanceSession $session,
        Student $student,
        array $data,
        ?User $actor = null,
        ?string $recordedAt = null,
        ?int $editingId = null,
    ): MemorizationLog {
        $this->guardSession($session);

        // 🔄 العميل أوف-لاين يولّد `uuid` التسميع ويصفّ به التسجيل والتصحيح معاً:
        // لا يملك مفتاحاً أساسياً يشير به إلى سجلٍّ لم يُنشأ على الخادم بعد. فإن
        // وصل معرّفٌ يطابق سجلاً قائماً كان الدفعُ تصحيحاً، وإلا كان تسجيلاً بمعرّفه.
        $log = $this->resolve($data['uuid'] ?? null, $editingId);
        $editingId = $log->exists ? $log->getKey() : null;

        $fromSurah = (int) $data['from_surah'];
        $fromAyah = (int) $data['from_ayah'];
        $toSurah = (int) $data['to_surah'];
        $toAyah = (int) $data['to_ayah'];

        $this->guardRange($fromSurah, $fromAyah, $toSurah, $toAyah);

        $grade = RecitationGrade::tryFrom((string) ($data['grade'] ?? ''));
        $institute = $session->courseCircle->circle->institute;

        $lines = Quran::linesForRange($fromSurah, $fromAyah, $toSurah, $toAyah);
        $newLines = $this->newLines($student, $fromSurah, $fromAyah, $toSurah, $toAyah, $editingId);
        $points = PointsSettings::for($institute)->quranPoints($newLines, $grade);

        return DB::transaction(function () use ($log, $student, $session, $data, $recordedAt, $fromSurah, $fromAyah, $toSurah, $toAyah, $grade, $lines, $newLines, $points, $actor): MemorizationLog {
            $log->fill([
                'student_id' => $student->id,
                'course_circle_id' => $session->course_circle_id,
                'attendance_session_id' => $session->id,
                'curriculum_item_id' => $data['curriculum_item_id'] ?? null,
                'date' => $recordedAt ?? $session->session_date,
                'type' => MemorizationType::tryFrom((string) ($data['type'] ?? '')) ?? MemorizationType::Hifz,
                'grade' => $grade,
                'from_surah' => $fromSurah,
                'from_ayah' => $fromAyah,
                'to_surah' => $toSurah,
                'to_ayah' => $toAyah,
                'juz' => blank($data['juz'] ?? null) ? null : (int) $data['juz'],
                'lines' => $lines,
                'new_lines' => $newLines,
                'points' => $points,
                'teacher_id' => $actor?->teacher?->id,
                'notes' => blank($data['notes'] ?? null) ? null : $data['notes'],
            ])->save();

            return $log;
        });
    }

    /**
     * السجلّ الذي يقصده الحفظ: القائم بمعرّفه أو بمفتاحه، أو سجلٌّ جديد يحمل
     * المعرّف الذي ولّده العميل — وإلّا لَتغيّر المعرّفُ بين الجهاز والخادم فصار
     * التصحيحُ من الجهاز نفسه تسجيلاً ثانياً.
     */
    private function resolve(?string $uuid, ?int $editingId): MemorizationLog
    {
        if ($editingId !== null) {
            return MemorizationLog::findOrFail($editingId);
        }

        if (blank($uuid)) {
            return new MemorizationLog;
        }

        // `withTrashed`: التسميع محذوفٌ حذفاً ناعماً، وقيدُ `unique(uuid)` يشمل
        // المحذوف. فإعادةُ إرسال المعرّف نفسه تُحيي الصفَّ ولا تصطدم بالقيد.
        $log = MemorizationLog::withTrashed()->where('uuid', $uuid)->first();

        if ($log !== null) {
            $log->restore();

            return $log;
        }

        $fresh = new MemorizationLog;
        $fresh->uuid = $uuid;

        return $fresh;
    }

    private function guardSession(AttendanceSession $session): void
    {
        if ($session->status === SessionStatus::Locked) {
            throw new RuntimeException('الجلسة مقفلة ولا تقبل التعديل.');
        }
    }

    private function guardRange(int $fromSurah, int $fromAyah, int $toSurah, int $toAyah): void
    {
        foreach ([[$fromSurah, $fromAyah], [$toSurah, $toAyah]] as [$surah, $ayah]) {
            $total = Quran::ayahs($surah);

            if ($total === 0) {
                throw new RuntimeException('رقم السورة خارج المصحف.');
            }

            if ($ayah < 1 || $ayah > $total) {
                throw new RuntimeException(Quran::name($surah).' فيها '.$total.' آية — رقم الآية خارج السورة.');
            }
        }

        if ([$fromSurah, $fromAyah] > [$toSurah, $toAyah]) {
            throw new RuntimeException('نهاية المدى قبل بدايته.');
        }
    }

    /**
     * الأسطر الجديدة وحدها: ما لم يسبق للطالب تسميعه، محسوباً بالآية ثم محوّلاً أسطراً.
     */
    private function newLines(Student $student, int $fromSurah, int $fromAyah, int $toSurah, int $toAyah, ?int $editingId): float
    {
        $map = $this->coverageMap->handle($student, $editingId);
        $newAyahs = BuildStudentCoverageMap::newAyahsIn($map, $fromSurah, $fromAyah, $toSurah, $toAyah);

        $lines = 0.0;

        foreach ($newAyahs as $surah => $ayahs) {
            $lines += Quran::linesOfAyahs($surah, $ayahs);
        }

        return round($lines, 2);
    }
}
