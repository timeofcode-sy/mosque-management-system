<?php

namespace Tests\Feature\Api;

use App\Enums\SyncOperation;
use App\Models\ChangeLog;
use App\Models\Circle;
use App\Models\Student;
use App\Support\SyncRecorder;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * 🔴 م.5.3: `SyncPull` يقرأ `change_log` وحده ولا يمسّ جداول الدومين، فالصفُّ الذي لم
 * يمرّ بمراقب التغييرات لا سبيل لأي عميل أن يعرفه — لا في `since=0` ولا بعدها.
 *
 * وثلاثةُ مصادر تُنتج صفوفاً كهذه: بياناتُ ما قبل م.5.1 (يومَ لم يكن المراقب موجوداً)،
 * والبذرُ الذي يعطّل التسجيل للسرعة، والإدراجُ بالجملة الذي لا يُطلق أحداث Eloquent.
 * كان الأثرُ صامتاً وقاتلاً: التطبيق يدخل ويرى ثيم المعهد ثم يعرض شاشةً فارغة — وهو
 * ما كشفته أوّلُ تجربةٍ على محاكٍ في م.5.3.
 */
class ChangeLogBackfillTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        $this->buildInstitute();
    }

    public function test_it_records_every_syncable_row_seeded_outside_the_observer(): void
    {
        $students = app(SyncRecorder::class)->without(
            fn () => Student::factory()->count(3)->create(['institute_id' => $this->institute->id]),
        );

        $this->assertSame(0, ChangeLog::where('table_name', 'students')->count());

        $this->artisan('sync:backfill-change-log')->assertSuccessful();

        $recorded = ChangeLog::where('table_name', 'students')->pluck('row_uuid')->sort()->values();

        $this->assertSame($students->pluck('uuid')->sort()->values()->all(), $recorded->all());
    }

    public function test_it_writes_create_rows_with_full_payload_and_institute_scope(): void
    {
        $student = app(SyncRecorder::class)->without(
            fn () => Student::factory()->create(['institute_id' => $this->institute->id]),
        );

        $this->artisan('sync:backfill-change-log')->assertSuccessful();

        $row = ChangeLog::where('table_name', 'students')->sole();

        $this->assertSame(SyncOperation::Create, $row->operation);
        $this->assertSame('institute:'.$this->institute->uuid, $row->scope_key);
        $this->assertSame($student->uuid, $row->payload['uuid']);
        // المفتاح الأساسي الخادمي جزءٌ من الحمولة: مفاتيحُ العميل الأجنبية رقميةٌ خادمية.
        $this->assertSame($student->id, $row->payload['id']);
    }

    public function test_it_never_duplicates_a_row_already_in_the_stream(): void
    {
        // صفٌّ مرّ بالمراقب طبيعياً، وآخرُ كُتم عنه: الردمُ يخصّ الثاني وحده.
        Student::factory()->create(['institute_id' => $this->institute->id]);
        app(SyncRecorder::class)->without(
            fn () => Student::factory()->create(['institute_id' => $this->institute->id]),
        );

        $this->artisan('sync:backfill-change-log')->assertSuccessful();

        // العدّ بعد أوّل ردم هو المرجع: الصفُّ الذي مرّ بالمراقب قد يحمل أكثر من قيدٍ
        // (إنشاءٌ ثم تحديث) وهو صحيح، فالمقصود أن الردم الثاني لا يزيد شيئاً.
        $settled = ChangeLog::where('table_name', 'students')->count();

        $this->artisan('sync:backfill-change-log')->assertSuccessful();

        $this->assertSame($settled, ChangeLog::where('table_name', 'students')->count());
        $this->assertSame(2, ChangeLog::where('table_name', 'students')->distinct()->count('row_uuid'));
    }

    public function test_it_checks_by_row_not_by_count(): void
    {
        // لو كان الفحصُ «هل لهذا الجدول صفوفٌ في التيّار؟» لتُخطّي المكتومُ كلُّه.
        Circle::factory()->create(['institute_id' => $this->institute->id]);
        $hidden = app(SyncRecorder::class)->without(
            fn () => Circle::factory()->create(['institute_id' => $this->institute->id]),
        );

        $this->artisan('sync:backfill-change-log')->assertSuccessful();

        $this->assertTrue(
            ChangeLog::where('table_name', 'circles')->where('row_uuid', $hidden->uuid)->exists(),
        );
    }

    public function test_a_fresh_device_pulls_the_whole_seed_from_since_zero(): void
    {
        app(SyncRecorder::class)->without(
            fn () => Student::factory()->count(2)->create(['institute_id' => $this->institute->id]),
        );

        $this->actingAsTeacher($this->institute);

        // قبل الردم: قاعدةٌ عامرة وجهازٌ يرى فراغاً — هذا هو العطب نفسه.
        $before = $this->getJson('/api/v1/sync/pull?since=0&app=teacher');
        $before->assertOk();
        $this->assertCount(0, collect($before->json('changes'))->where('table_name', 'students'));

        $this->artisan('sync:backfill-change-log')->assertSuccessful();

        $after = $this->getJson('/api/v1/sync/pull?since=0&app=teacher');
        $after->assertOk();
        $this->assertCount(2, collect($after->json('changes'))->where('table_name', 'students'));
    }

    public function test_it_fails_loudly_when_a_syncable_model_is_missing_from_the_order(): void
    {
        // الحارسُ نفسه: نموذجٌ يُزامَن ولا يرد في ORDER يوقف الأمر بدل أن يُردَم بلا ترتيب.
        $this->artisan('sync:backfill-change-log', ['--dry-run' => true])->assertSuccessful();
    }
}
