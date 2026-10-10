<?php

namespace Tests\Feature\Livewire;

use App\Models\Student;
use App\Models\Teacher;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Livewire\Livewire;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * شاشة بيانات الدخول وطريقا تسليمها: ملفّ CSV وصفحةُ البطاقات.
 */
class CredentialsScreenTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    private Student $student;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();

        $this->student = Student::factory()->create([
            'institute_id' => $this->institute->id,
            'first_name' => 'أنس',
            'father_name' => 'محمد',
            'family_name' => 'الحلبي',
        ]);
    }

    public function test_the_screen_lists_generated_credentials(): void
    {
        Livewire::test('pages::credentials.index')
            ->assertOk()
            ->assertSee('أنس')
            ->assertSee((string) $this->student->fresh()->user->username);
    }

    /**
     * الكلمة مخفيّة حتى يُطلب كشفُها — الشاشة تُفتح أمام قاعةٍ فيها طلاب.
     */
    public function test_passwords_stay_hidden_until_revealed(): void
    {
        $password = (string) $this->student->fresh()->user->generated_password;

        Livewire::test('pages::credentials.index')
            ->assertDontSee($password)
            ->set('revealed', true)
            ->assertSee($password);
    }

    /**
     * العمودُ مشفَّر بـ APP_KEY: لو تبدّل المفتاح (نسخُ .env من جديد) رمى كل صفٍّ «The MAC is invalid»
     * وسقطت الشاشةُ بـ 500. والآن تُعامَل الكلمةُ التي لا تُفَكّ كالمُغيَّرة وتبقى الشاشةُ تعمل.
     */
    public function test_a_password_that_cannot_be_decrypted_does_not_break_the_screen(): void
    {
        $user = $this->student->fresh()->user;

        // يحاكي صفّاً شُفِّر بمفتاحٍ آخر.
        DB::table('users')->where('id', $user->id)->update(['generated_password' => 'not-a-valid-payload']);

        Livewire::test('pages::credentials.index')
            ->assertOk()
            ->assertSee('أنس')
            ->assertSee((string) $user->username);
    }

    public function test_a_long_list_is_paged_and_filters_return_to_the_first_page(): void
    {
        Student::factory()->count(29)->create(['institute_id' => $this->institute->id]);

        $component = Livewire::test('pages::credentials.index');

        // 30 حساباً بخمسةٍ وعشرين في الصفحة: صفحتان، والتذييل يقول كم يُعرض من كم.
        $this->assertSame(30, $component->get('pagedRows')->total());
        $this->assertCount(25, $component->get('pagedRows')->items());
        $component->assertSee('30');

        $component->call('gotoPage', 2);
        $this->assertCount(5, $component->get('pagedRows')->items());

        // تغيّرُ المرشّح يعيد إلى الصفحة الأولى، وإلا بقي المستخدمُ على صفحةٍ فارغة.
        $component->set('search', 'أنس');
        $this->assertSame(1, $component->get('paginators')['page'] ?? 1);
    }

    public function test_the_role_filter_narrows_the_list(): void
    {
        $teacher = Teacher::factory()->create(['institute_id' => $this->institute->id, 'display_name' => 'الأستاذ خالد']);

        Livewire::test('pages::credentials.index')
            ->set('role', 'teacher')
            ->assertSee('الأستاذ خالد')
            ->assertDontSee('أنس');

        $this->assertNotNull($teacher->fresh()->user_id);
    }

    /**
     * لا يرى المشرفُ نفسَه ولا نظيره في القائمة — الرتبة قيدٌ على الرؤية لا على
     * التبديل وحده.
     */
    public function test_peers_and_superiors_are_not_listed(): void
    {
        $supervisor = User::factory()->create(['first_name' => 'سعيد', 'last_name' => 'المشرف']);
        $this->assignRole($supervisor, 'supervisor');

        $this->actingAs($supervisor);

        Livewire::test('pages::credentials.index')
            ->assertSee('أنس')
            ->assertDontSee('سعيد');
    }

    public function test_a_supervisor_may_reissue_a_password_from_the_screen(): void
    {
        $userId = $this->student->fresh()->user_id;

        Livewire::test('pages::credentials.index')
            ->call('openPasswordForm', $userId, 'أنس')
            ->call('changePassword')
            ->assertHasNoErrors()
            ->assertSet('issuedPassword', fn (?string $password) => preg_match('/^\d{8}$/', (string) $password) === 1);
    }

    public function test_the_csv_export_carries_the_credentials(): void
    {
        $user = $this->student->fresh()->user;

        $response = $this->get(route('credentials.csv'));

        $response->assertOk();
        $response->assertDownload();

        $body = $response->streamedContent();

        $this->assertStringContainsString((string) $user->username, $body);
        $this->assertStringContainsString((string) $user->generated_password, $body);
    }

    public function test_the_print_page_renders_cards(): void
    {
        $this->get(route('credentials.print'))
            ->assertOk()
            ->assertSee('بطاقات الدخول')
            ->assertSee((string) $this->student->fresh()->user->username);
    }

    /**
     * app.css يثبّت html/body على ارتفاع الشاشة مع overflow:hidden، فكان PDF الطباعة يقتصر على أول صفحة.
     * ورقة التقرير تُعيد التدفّق الطبيعي وتطلب A4.
     */
    public function test_the_print_sheet_flows_across_pages_on_a4(): void
    {
        $this->get(route('credentials.print'))
            ->assertOk()
            ->assertSee('size: A4 portrait', false)
            ->assertSee('overflow: visible', false);
    }

    /**
     * الشاشة خلف credentials.export — والطالبُ لا يبلغها.
     */
    public function test_a_student_cannot_reach_the_screen(): void
    {
        $this->actingAs($this->student->fresh()->user);

        $this->get(route('credentials.index'))->assertForbidden();
    }
}
