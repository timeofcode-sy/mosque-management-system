<?php

namespace App\Console\Commands;

use App\Contracts\Syncable;
use App\Enums\SyncOperation;
use App\Models\AbsenceExcuse;
use App\Models\Announcement;
use App\Models\Attendance;
use App\Models\AttendanceSession;
use App\Models\ChangeLog;
use App\Models\Circle;
use App\Models\Course;
use App\Models\CourseCircle;
use App\Models\CourseCircleTeacher;
use App\Models\Curriculum;
use App\Models\CurriculumItem;
use App\Models\CustomField;
use App\Models\CustomFieldValue;
use App\Models\Enrollment;
use App\Models\Evaluation;
use App\Models\Guardian;
use App\Models\GuardianStudent;
use App\Models\Institute;
use App\Models\MemorizationLog;
use App\Models\PersonalTrait;
use App\Models\Shift;
use App\Models\ShiftDay;
use App\Models\Student;
use App\Models\StudentCurriculumProgress;
use App\Models\StudentPoint;
use App\Models\StudentTrait;
use App\Models\StudentTransfer;
use App\Models\Tag;
use App\Models\Teacher;
use App\Models\TeacherAttendance;
use App\Support\SyncRecorder;
use Illuminate\Console\Command;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;
use SplFileInfo;
use Symfony\Component\Finder\Finder;

/**
 * يكتب صفَّ `create` في change_log لكل صفٍّ مُزامَنٍ لا أثر له فيه — ويعيد التيّار كاملاً.
 *
 * 🔴 م.5.3: `sync/pull` يقرأ **change_log وحده** ولا يمسّ جداول الدومين أبداً
 * (`SyncPull::handle`). فالصفُّ الذي لم يمرّ بالمراقب لا سبيل لأي عميل أن يعرفه:
 * لا في `since=0` ولا بعدها — التيّارُ تيّارُ تغييرات لا لقطةُ حالة.
 *
 * وثلاثةُ مصادر تُنتج صفوفاً كهذه:
 *   1. **بيانات ما قبل م.5.1** — يومَ لم يكن المراقب موجوداً أصلاً.
 *   2. **البذر** — `DatabaseSeeder` يعطّل التسجيل ليبقى `migrate:fresh --seed` سريعاً.
 *   3. **الإدراج بالجملة** (`insert()` أو استيرادٌ من نظامٍ قديم) — لا يُطلق أحداث Eloquent.
 *
 * والأثر كان صامتاً وقاتلاً: التطبيق يدخل ويرى ثيم المعهد (من `/bootstrap`) ثم يعرض
 * «لم تُسنَد إليك حلقة» — لأن مخزنه فارغ، لا لأن الإسناد ناقص.
 *
 * الأمر **مُتماثِل (idempotent)**: يتخطّى كل صفٍّ له أثرٌ في التيّار، فتشغيلُه مرّتين
 * لا يضاعف شيئاً، وتشغيلُه بعد ترحيلٍ جزئي يكمل الناقص وحده.
 */
class BackfillChangeLog extends Command
{
    protected $signature = 'sync:backfill-change-log {--dry-run : اعرض ما سيُكتب بلا كتابة}';

    protected $description = 'يردم change_log بصفوفٍ مُزامَنة لم تمرّ بمراقب التغييرات (بذرٌ أو بياناتُ ما قبل م.5.1)';

    /**
     * ترتيبُ الأب قبل ابنه.
     *
     * العميل يطبّق بترتيب `server_seq` تصاعدياً، فصفُّ الحضور الذي يسبق جلستَه يصل إلى
     * مخزنٍ لا يعرف الجلسة بعد. الترتيبُ هنا يجعل التيّار المردوم يُقرأ كما لو أن الصفوف
     * أُنشئت بترتيبها الطبيعي.
     *
     * وكلُّ نموذجٍ يُزامَن ولا يرد في هذه القائمة **يوقف الأمر بخطأ** لا يُسجَّل في آخرها
     * بصمت: إضافةُ جدولٍ مُزامَنٍ جديد قرارٌ يستحقّ أن يُوضَع في ترتيبه بيد كاتبه.
     *
     * @var list<class-string<Model>>
     */
    private const array ORDER = [
        Institute::class,
        Tag::class,
        PersonalTrait::class,
        CustomField::class,
        Curriculum::class,
        CurriculumItem::class,
        Shift::class,
        ShiftDay::class,
        Circle::class,
        Course::class,
        CourseCircle::class,
        Teacher::class,
        CourseCircleTeacher::class,
        Guardian::class,
        Student::class,
        GuardianStudent::class,
        StudentTrait::class,
        StudentTransfer::class,
        CustomFieldValue::class,
        Enrollment::class,
        AttendanceSession::class,
        Attendance::class,
        TeacherAttendance::class,
        AbsenceExcuse::class,
        MemorizationLog::class,
        Evaluation::class,
        StudentCurriculumProgress::class,
        StudentPoint::class,
        Announcement::class,
    ];

    public function handle(SyncRecorder $recorder): int
    {
        if (($missing = $this->unorderedModels()) !== []) {
            $this->error('نماذجُ تُزامَن ولم تُرتَّب في BackfillChangeLog::ORDER:');
            $this->line('  '.implode(PHP_EOL.'  ', $missing));
            $this->line('ضَعْ كلاً منها بعد أبيه — الترتيبُ شرطُ صحّة لا تجميل.');

            return self::FAILURE;
        }

        $dryRun = (bool) $this->option('dry-run');
        $total = 0;
        $orphans = 0;

        foreach (self::ORDER as $class) {
            [$written, $skipped] = $this->backfill($class, $recorder, $dryRun);
            $total += $written;
            $orphans += $skipped;

            if ($written > 0) {
                $this->line(str_pad((new $class)->getTable(), 30).Str::padLeft((string) $written, 6));
            }
        }

        if ($orphans > 0) {
            // صفٌّ لا يحسم معهده خارج كل نطاق، فلا عميلَ يقرؤه — نفس تخطّي المراقب له.
            $this->comment("{$orphans} صفّاً بلا معهد — خارج النطاق فلا يُبثّ.");
        }

        $this->info($dryRun
            ? "سيُكتب {$total} صفّاً في change_log (تشغيلٌ جافّ — لم يُكتب شيء)."
            : "كُتب {$total} صفّاً في change_log.");

        return self::SUCCESS;
    }

    /**
     * @param  class-string<Model>  $class
     * @return array{0: int, 1: int} المكتوبُ فعلاً، والمتخطّى لأنه بلا معهد
     */
    private function backfill(string $class, SyncRecorder $recorder, bool $dryRun): array
    {
        $model = new $class;

        // ما سبق تسجيله — بالمعرّف لا بالعدد: صفٌّ قديمٌ في التيّار وصفٌّ جديدٌ خارجه
        // يتعايشان في نفس الجدول، والردمُ يخصّ الثاني وحده.
        $recorded = ChangeLog::query()
            ->where('table_name', $model->getTable())
            ->pluck('row_uuid')
            ->flip();

        $written = 0;
        $skipped = 0;

        // الصفوفُ المحذوفة ليّناً تُترَك: العميلُ لم يعرفها قطّ فلا معنى لأن نأمره بحذفها.
        $class::query()->orderBy('id')->chunkById(500, function ($rows) use ($recorded, $recorder, $dryRun, &$written, &$skipped): void {
            foreach ($rows as $row) {
                if ($recorded->has($row->getAttribute('uuid'))) {
                    continue;
                }

                // المسجّل يتخطّى صامتاً صفّاً لا يحسم معهده (منهجٌ عامّ أو سمةٌ مشتركة)،
                // فيُعدّ هنا على حدة — وإلا أعلن الأمرُ عدداً أكبر ممّا كتب فعلاً.
                if ($row->syncInstituteId() === null) {
                    $skipped++;

                    continue;
                }

                // record() هو نفسه مسارُ المراقب: نفس شكل الحمولة ونفس حسم scope_key.
                // فلا ينشأ شكلان للصفّ الواحد بحسب من كتبه.
                if (! $dryRun) {
                    $recorder->record($row, SyncOperation::Create);
                }

                $written++;
            }
        });

        return [$written, $skipped];
    }

    /**
     * نماذجُ `Syncable` في app/Models غيرُ المذكورة في ORDER.
     *
     * @return list<string>
     */
    private function unorderedModels(): array
    {
        $found = [];

        foreach (Finder::create()->files()->name('*.php')->in(app_path('Models')) as $file) {
            /** @var SplFileInfo $file */
            $class = 'App\\Models\\'.$file->getFilenameWithoutExtension();

            if (is_subclass_of($class, Syncable::class)) {
                $found[] = $class;
            }
        }

        return array_values(array_diff($found, self::ORDER));
    }
}
