<?php

namespace Tests\Feature\Actions;

use App\Actions\ImportInstitute;
use App\Enums\GuardianRelation;
use App\Models\ChangeLog;
use App\Models\CourseCircleTeacher;
use App\Models\CustomFieldValue;
use App\Models\Guardian;
use App\Models\Institute;
use App\Models\Student;
use App\Support\XlsxReader;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\Concerns\WritesXlsx;
use Tests\TestCase;

class ImportInstituteTest extends TestCase
{
    use RefreshDatabase, WritesXlsx;

    protected function setUp(): void
    {
        parent::setUp();

        // الإنتاج يُبذر الأدوار وحدها — والمناهج العامة يزرعها الاستيراد إن غابت.
        $this->seed(RolesAndPermissionsSeeder::class);
    }

    public function test_it_builds_the_whole_institute_from_the_workbook(): void
    {
        $result = app(ImportInstitute::class)->handle($this->workbook());

        $this->assertSame([], $result['errors']);

        $institute = Institute::query()->sole();
        $course = $institute->currentCourse();

        $this->assertSame('معهد التجربة', $institute->name);
        $this->assertSame('#7d0a0a', $institute->settings['theme']['primary']);
        $this->assertSame('2026-09-19', $course->starts_on->toDateString());
        $this->assertSame([0, 2, 4], $course->shifts()->sole()->days()->orderBy('weekday')->pluck('weekday')->all());

        // الحلقة بلا دوام تُنشأ ولا تعمل في الدورة، والموقوفة تبقى موقوفة.
        $this->assertSame(3, $institute->circles()->count());
        $this->assertSame(1, $course->courseCircles()->count());
        $this->assertFalse($institute->circles()->where('name', 'حلقة قديمة')->sole()->is_active);
        $this->assertSame('يوسف البري', CourseCircleTeacher::query()->sole()->teacher->display_name);

        $jaber = Student::query()->where('first_name', 'جابر')->sole();
        $hamza = Student::query()->where('first_name', 'حمزة')->sole();

        $this->assertSame('2013-05-07', $jaber->birth_date->toDateString());
        $this->assertSame('0947344640', $jaber->phone);

        // أخوان من عائلةٍ واحدة يتشاركان سجلّي الأب والأم.
        $this->assertTrue($jaber->father()->is($hamza->father()));
        $this->assertTrue($jaber->mother()->is($hamza->mother()));
        $this->assertSame(['هنادي', 'الشيخ حسن'], [$jaber->mother()->first_name, $jaber->mother()->family_name]);
        $this->assertSame(['فواز', 'الزغلول'], [$jaber->father()->first_name, $jaber->father()->family_name]);
        $this->assertSame('0951320273', $jaber->father()->phone);
        $this->assertFalse($jaber->father()->is_alive);

        $abdulrahman = Student::query()->where('first_name', 'عبد الرحمن')->sole();
        $this->assertTrue($abdulrahman->father()->is($jaber->father()));
        $this->assertSame('حنان السيد حسن', $abdulrahman->mother()->full_name);

        $this->assertNull(Student::query()->where('father_name', 'بن')->sole()->father());
        $this->assertSame(3, Guardian::query()->count());

        // السور المحفوظة قبل الالتحاق: تسميعُ «حفظ» قبل بداية الدورة، بلا نقاط.
        $this->assertSame([18, 36], $hamza->memorizationLogs()->orderBy('from_surah')->pluck('from_surah')->all());
        $this->assertSame('2026-09-18', $hamza->memorizationLogs()->first()->date->toDateString());
        $this->assertEquals(0, $hamza->memorizationLogs()->sum('points'));
        $this->assertNotNull($hamza->curriculumProgress()->whereHas('curriculumItem', fn ($query) => $query->where('code', 'juz-15'))->first());

        $this->assertSame(
            ['juz-29', 'juz-30', 'tuhfat-al-atfal'],
            $jaber->curriculumProgress()->with('curriculumItem')->get()->pluck('curriculumItem.code')->sort()->values()->all(),
        );
        $this->assertSame('ملك', CustomFieldValue::query()->where('entity_id', $jaber->id)->sole()->value);

        $this->assertSame('الإمام النووي', $jaber->activeEnrollment()->courseCircle->circle->name);
        $this->assertNull($hamza->activeEnrollment());

        // كلُّ ذلك يصل التطبيقات: التسجيل معطّلٌ أثناء الكتابة ثم يُردم.
        $this->assertSame(4, ChangeLog::query()->where('table_name', 'students')->count());
        $this->assertNotNull($jaber->fresh()->user->generated_password);
    }

    public function test_accounts_can_be_born_without_passwords_and_issued_later(): void
    {
        app(ImportInstitute::class)->handle($this->workbook(), withoutPasswords: true);

        $user = Student::query()->where('first_name', 'جابر')->sole()->user;

        $this->assertSame('student', preg_replace('/\d+$/', '', $user->username));
        $this->assertNull($user->generated_password);

        $this->artisan('accounts:issue-passwords', ['institute' => 'معهد التجربة'])->assertSuccessful();

        $password = $user->fresh()->generated_password;
        $this->assertMatchesRegularExpression('/^\d{8}$/', $password);
        $this->assertTrue(Hash::check($password, $user->fresh()->password));

        // من صدرت له كلمةٌ لا يُمسّ في المرّة الثانية.
        $this->artisan('accounts:issue-passwords', ['institute' => 'معهد التجربة'])->assertSuccessful();
        $this->assertSame($password, $user->fresh()->generated_password);
    }

    /**
     * التصدير بأوراق الاستيراد نفسها: ما يُصدَّر يُعاد استيرادُه فيخرج المعهد نفسه.
     */
    public function test_the_export_imports_back_into_the_same_institute(): void
    {
        app(ImportInstitute::class)->handle($this->workbook(), withoutPasswords: true);

        $path = tempnam(sys_get_temp_dir(), 'xlsx').'.xlsx';
        $this->artisan('institute:export', ['institute' => 'معهد التجربة', 'file' => $path])->assertSuccessful();

        $sheets = XlsxReader::read($path);
        $this->assertSame('لم تُصدَر بعد', collect($sheets['الحسابات'])->firstWhere(0, 'جابر فواز الزغلول')[3] ?? null);
        $sheets['المعهد'][1][1] = 'معهد التجربة الثاني';

        $result = app(ImportInstitute::class)->handle($sheets);

        $this->assertSame([], $result['errors']);
        $copy = $result['institute'];
        $jaber = $copy->students()->where('first_name', 'جابر')->sole()->load('guardians');
        $abdulrahman = $copy->students()->where('first_name', 'عبد الرحمن')->sole()->load('guardians');

        $this->assertSame(3, $copy->guardians()->count());
        $this->assertTrue($abdulrahman->father()->is($jaber->father()));
        $this->assertFalse($jaber->father()->is_alive);
        $this->assertSame('الإمام النووي', $jaber->activeEnrollment()->courseCircle->circle->name);
        $this->assertSame([18, 36], $copy->students()->where('first_name', 'حمزة')->sole()
            ->memorizationLogs()->orderBy('from_surah')->pluck('from_surah')->all());
    }

    public function test_a_dry_run_validates_everything_and_keeps_nothing(): void
    {
        $result = app(ImportInstitute::class)->handle($this->workbook(), dryRun: true);

        $this->assertSame([], $result['errors']);
        $this->assertSame(4, $result['counts']['الطلاب']);
        $this->assertSame(0, Institute::query()->count());
        $this->assertSame(0, Student::query()->count());
    }

    public function test_a_broken_workbook_writes_nothing_and_says_where(): void
    {
        $workbook = $this->workbook();
        $workbook['الطلاب'][1][9] = 'حلقة لا وجود لها';
        $workbook['الطلاب'][2][10] = '31';

        $result = app(ImportInstitute::class)->handle($workbook);

        $this->assertContains('الطلاب ط001: الحلقة «حلقة لا وجود لها» ليست في ورقة الحلقات.', $result['errors']);
        $this->assertContains('الطلاب ط002: «31» ليس رقم جزء (1 إلى 30).', $result['errors']);
        $this->assertSame(0, Institute::query()->count());
    }

    public function test_a_full_circle_rolls_the_whole_import_back(): void
    {
        $workbook = $this->workbook();
        $workbook['الحلقات'][1][3] = '1';
        $workbook['الطلاب'][2][9] = 'الإمام النووي';

        $result = app(ImportInstitute::class)->handle($workbook);

        $this->assertStringContainsString('بلغت طاقتها', $result['errors'][0]);
        $this->assertSame(0, Institute::query()->count());
        $this->assertSame(0, Guardian::query()->count());
    }

    public function test_an_existing_institute_is_never_merged_into(): void
    {
        Institute::factory()->create(['name' => 'معهد التجربة']);

        $result = app(ImportInstitute::class)->handle($this->workbook());

        $this->assertStringContainsString('موجودٌ أصلاً', $result['errors'][0]);
        $this->assertSame(1, Institute::query()->count());
    }

    public function test_the_command_reads_the_xlsx_file(): void
    {
        $path = $this->writeXlsx($this->workbook());

        $this->artisan('institute:import', ['file' => $path, '--dry-run' => true])
            ->expectsOutputToContain('المصنّف سليم')
            ->assertSuccessful();

        $this->artisan('institute:import', ['file' => $path])->assertSuccessful();

        $this->assertSame(4, Student::query()->count());
        $this->assertSame(2, Guardian::query()
            ->whereHas('students', fn ($query) => $query->where('guardian_student.relation', GuardianRelation::Mother->value))
            ->count());
    }

    /**
     * مصنّفٌ صغير بالبنية التي يكتبها scripts/import: أخوان من عائلةٍ واحدة، أحدهما في حلقة.
     *
     * @return array<string, list<list<?string>>>
     */
    private function workbook(): array
    {
        return [
            'المعهد' => [
                ['البند', 'القيمة'],
                ['الاسم', 'معهد التجربة'],
                ['الاسم المختصر', 'التجربة'],
                ['الدورة', 'دورة 2026'],
                ['بداية الدورة', '2026-09-19'],
                ['نهاية الدورة', '2026-12-20'],
                ['الإعدادات', '{"theme": {"primary": "#7d0a0a"}}'],
            ],
            'الدوامات' => [
                ['الدوام', 'البداية', 'النهاية', 'الترتيب', 'الأيام'],
                ['ثانوي', '20:00', '21:30', '1', 'الأحد، الثلاثاء، الخميس'],
            ],
            'الأساتذة' => [
                ['الاسم', 'الجوال'],
                ['يوسف البري', '960982416'],
            ],
            'الحلقات' => [
                ['الحلقة', 'الدوام', 'الأستاذ', 'الطاقة', 'مفعّلة', 'الترتيب'],
                ['الإمام النووي', 'ثانوي', 'يوسف البري', '15', 'نعم', '1'],
                ['سلمان الفارسي', null, null, null, 'نعم', '2'],
                ['حلقة قديمة', null, null, null, 'لا', '3'],
            ],
            'الواصفات' => [
                ['العنوان', 'المفتاح', 'النوع', 'الخيارات', 'المجموعة', 'مطلوبة'],
                ['السكن', 'housing', 'select', 'ملك، أجار، عائلي', 'البيانات العائلية', 'لا'],
            ],
            'الطلاب' => [
                ['المرجع', 'الاسم', 'اسم الأب', 'الكنية', 'تاريخ الولادة', 'جوال الطالب', 'رمز الأب', 'جوال الأب', 'الأب متوفى',
                    'الحلقة', 'الأجزاء المحفوظة', 'محفوظات أخرى', 'اسم الأم', 'كنية الأم', 'السكن', 'عمود للمراجعة فقط',
                    'رمز الأم', 'السور المحفوظة'],
                ['ط001', 'جابر', 'فواز', 'الزغلول', '41401', '947344640', 'أ001', '0951320273', 'نعم',
                    'الإمام النووي', '30، 29', 'تحفة الأطفال', 'هنادي', 'الشيخ حسن', 'ملك', 'يُتجاهل', 'م001', null],
                ['ط002', 'حمزة', 'فواز', 'الزغلول', '2011', null, 'أ001', null, null,
                    null, null, null, 'هنادي', 'الشيخ حسن', null, null, 'م001', 'الكهف، يس'],
                // أخٌ لأب: يشارك أخويه سجلّ الأب وحده.
                ['ط003', 'عبد الرحمن', 'فواز', 'الزغلول', null, null, 'أ001', null, null,
                    null, null, null, 'حنان', 'السيد حسن', null, null, null, null],
                // اسم أبٍ مجهول: لا يُنشأ له وليّ أمر.
                ['ط004', 'قيصر', 'بن', 'رمضان', null, null, null, null, null,
                    null, null, null, null, null, null, null, null, null],
            ],
        ];
    }
}
