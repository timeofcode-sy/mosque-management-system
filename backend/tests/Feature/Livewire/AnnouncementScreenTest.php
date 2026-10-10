<?php

namespace Tests\Feature\Livewire;

use App\Models\Announcement;
use App\Models\Enrollment;
use App\Models\Student;
use App\Queries\AnnouncementQuery;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

/**
 * شاشةُ الإعلانات — ✅ م.8.1، **الطرفُ الكاتب**.
 *
 * وما تحرسه: أن يولد الجدولُ حيّاً لا حمولةً ميتة، وأن يبقى ما يُكتب متّسقاً مع
 * ما يقرؤه الطالبُ في نقطته.
 */
class AnnouncementScreenTest extends TestCase
{
    use BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildInstitute();
    }

    public function test_the_screen_renders(): void
    {
        $this->get(route('announcements.index'))->assertOk();
    }

    public function test_publishing_writes_an_announcement_the_student_can_read(): void
    {
        Livewire::test('pages::announcements.index')
            ->set('title', 'بداية الدورة')
            ->set('body', 'تبدأ الدورةُ الأحد بإذن الله.')
            ->set('scope', 'all')
            ->set('publishNow', true)
            ->call('save')
            ->assertHasNoErrors();

        $announcement = Announcement::query()->sole();

        $this->assertSame('بداية الدورة', $announcement->title);
        $this->assertSame($this->institute->id, $announcement->institute_id);
        $this->assertNotNull($announcement->published_at);
        $this->assertNull($announcement->scope_ids);
    }

    /**
     * المسودّةُ تُحفظ ولا تظهر — و`published_at` فارغةٌ هي ما يفصلهما.
     */
    public function test_a_draft_is_saved_unpublished(): void
    {
        Livewire::test('pages::announcements.index')
            ->set('title', 'مسودّة')
            ->set('body', 'نصّ.')
            ->set('publishNow', false)
            ->call('save')
            ->assertHasNoErrors();

        $this->assertNull(Announcement::query()->sole()->published_at);
    }

    /**
     * نطاقُ «حلقة» بلا حلقةٍ إعلانٌ لا يقرؤه أحد — يُمنع في الاستمارة.
     */
    public function test_a_circle_scope_without_a_circle_is_rejected(): void
    {
        Livewire::test('pages::announcements.index')
            ->set('title', 'عنوان')
            ->set('body', 'نصّ.')
            ->set('scope', 'circle')
            ->set('circleIds', [])
            ->call('save')
            ->assertHasErrors('circleIds');
    }

    /**
     * 🔑 تحويلُ النطاق إلى «الكلّ» **يمحو المعرّفات** — وإلا بدا الإعلانُ عامّاً
     * ويحمل قائمةً تناقضه، فيقرؤها من يبني عليها لاحقاً.
     */
    public function test_switching_to_the_wide_scope_clears_the_circle_ids(): void
    {
        $circle = $this->makeCourseCircle();

        $announcement = Announcement::create([
            'institute_id' => $this->institute->id,
            'title' => 'لحلقةٍ',
            'body' => 'نصّ.',
            'scope' => 'circle',
            'scope_ids' => [$circle->id],
            'published_at' => now(),
        ]);

        Livewire::test('pages::announcements.index')
            ->call('edit', $announcement)
            ->set('scope', 'all')
            ->call('save')
            ->assertHasNoErrors();

        $this->assertNull($announcement->refresh()->scope_ids);
        $this->assertSame('all', $announcement->scope);
    }

    /**
     * السحبُ إخفاءٌ لا حذف — فمن سحبه بالخطأ يعيده.
     */
    public function test_unpublishing_hides_without_deleting(): void
    {
        $announcement = Announcement::create([
            'institute_id' => $this->institute->id,
            'title' => 'منشور',
            'body' => 'نصّ.',
            'scope' => 'all',
            'published_at' => now(),
        ]);

        Livewire::test('pages::announcements.index')->call('unpublish', $announcement);

        $this->assertNull($announcement->refresh()->published_at);
        $this->assertDatabaseCount('announcements', 1);
    }

    /**
     * الأزرارُ تمرّر ما يمرّره المتصفّح لا ما يمرّره الاختبار: مفتاحُ المسار نصّيٌّ (uuid). كان الزرّان يمرّران
     * الرقمَ فيفشل ربطُ النموذج بـ 404 وتظهر صفحةُ الخطأ فوق الشاشة.
     */
    public function test_edit_and_unpublish_work_with_the_key_the_buttons_send(): void
    {
        $announcement = Announcement::create([
            'institute_id' => $this->institute->id,
            'title' => 'منشور',
            'body' => 'نصّ.',
            'scope' => 'all',
            'published_at' => now(),
        ]);

        $component = Livewire::test('pages::announcements.index')
            ->assertSeeHtml("wire:click=\"edit('{$announcement->uuid}')\"")
            ->assertSeeHtml("wire:click=\"unpublish('{$announcement->uuid}')\"");

        $component->call('edit', $announcement->uuid)->assertSet('title', 'منشور');
        $component->call('unpublish', $announcement->uuid);

        $this->assertNull($announcement->refresh()->published_at);
    }

    /**
     * 🔴 عيبٌ حقيقي: مربّعاتُ الحلقات في المتصفّح تُرسل معرّفاتٍ **نصّية** ("3") فخُزّنت في json نصوصاً،
     * بينما يبحث الطالبُ بالرقم (whereJsonContains) فلا يطابق شيءٌ ولا يصل إعلانُ الحلقة أحداً.
     * اختبارُ الـAPI كان يكتب أرقاماً مباشرةً فلم يرَ الفرق.
     */
    public function test_a_circle_announcement_written_from_the_form_reaches_its_students(): void
    {
        $circle = $this->makeCourseCircle();
        $other = $this->makeCourseCircle();
        $student = Student::factory()->create(['institute_id' => $this->institute->id]);
        Enrollment::factory()->create([
            'course_circle_id' => $circle->id,
            'student_id' => $student->id,
            'enrolled_on' => '2026-09-01',
        ]);

        Livewire::test('pages::announcements.index')
            ->set('title', 'لحلقةٍ بعينها')
            ->set('body', 'نصّ.')
            ->set('scope', 'circle')
            ->set('circleIds', [(string) $circle->id])
            ->set('publishNow', true)
            ->call('save')
            ->assertHasNoErrors();

        $announcement = Announcement::where('title', 'لحلقةٍ بعينها')->firstOrFail();

        // أرقامٌ صحيحة في json لا نصوص.
        $this->assertSame([$circle->id], $announcement->scope_ids);

        $titles = app(AnnouncementQuery::class)->forStudent($student)->pluck('title')->all();
        $this->assertSame(['لحلقةٍ بعينها'], $titles);

        $outsider = Student::factory()->create(['institute_id' => $this->institute->id]);
        Enrollment::factory()->create([
            'course_circle_id' => $other->id,
            'student_id' => $outsider->id,
            'enrolled_on' => '2026-09-01',
        ]);
        $this->assertSame([], app(AnnouncementQuery::class)->forStudent($outsider)->pluck('title')->all());
    }

    public function test_the_form_saves_the_chosen_audiences_and_refuses_none(): void
    {
        $component = Livewire::test('pages::announcements.index')
            ->set('title', 'للأولياء والأساتذة')
            ->set('body', 'نصّ.')
            ->set('scope', 'all')
            ->set('publishNow', true);

        // فئةٌ واحدة على الأقل: إعلانٌ بلا قرّاء لا يراه أحد.
        $component->set('audience', [])->call('save')->assertHasErrors(['audience']);

        $component->set('audience', ['guardians', 'teachers'])->call('save')->assertHasNoErrors();

        $announcement = Announcement::where('title', 'للأولياء والأساتذة')->firstOrFail();
        $this->assertSame(['guardians', 'teachers'], $announcement->audience);

        // وما لا يُعرف من الفئات يُرفض.
        $component->set('audience', ['everyone'])->call('save')->assertHasErrors(['audience.0']);
    }
}
