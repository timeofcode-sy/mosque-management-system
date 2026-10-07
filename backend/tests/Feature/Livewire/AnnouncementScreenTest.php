<?php

namespace Tests\Feature\Livewire;

use App\Models\Announcement;
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
}
