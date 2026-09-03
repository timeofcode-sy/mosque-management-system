<?php

namespace App\Concerns;

use App\Models\Course;
use App\Models\Institute;
use App\Support\PanelScope;
use Illuminate\Support\Facades\Auth;
use Livewire\Attributes\Computed;

/**
 * يمنح مكوّنات اللوحة المعهدَ العامل والدورةَ الجارية.
 *
 * الحسم نفسه يعيش في App\Support\PanelScope كي يتشاركه المكوّن والوسيط
 * (SetPanelInstituteScope) معاً: الوسيط يضبط مفتاح الفريق قبل middleware الصلاحيات،
 * والمكوّن يضبطه في طلبات Livewire التي لا تمرّ بطريق مسمّى.
 * يعود بـ null قبل إنشاء أول معهد، ولمن لا معهد مرتبطاً بحسابه — الشاشات تتعامل
 * مع ذلك بحالة فارغة أو تحويل.
 */
trait InteractsWithInstitute
{
    /**
     * مفتاح فريق Spatie يُضبط في كل دورة طلب لا في mount() وحده.
     *
     * لولا ذلك لعادت can() بـ false في أي استدعاء لاحق (زر «قفل نهائي» مثلاً)، لأن
     * mount() لا يُستدعى إلا مرّةً واحدة عند أول تصيير.
     */
    public function bootedInteractsWithInstitute(): void
    {
        $this->institute;
    }

    #[Computed]
    public function institute(): ?Institute
    {
        return PanelScope::resolve();
    }

    /**
     * الدورة الجارية — نطاق كل الشاشات التشغيلية (الدوامات، الحلقات، التسجيل).
     */
    #[Computed]
    public function currentCourse(): ?Course
    {
        return $this->institute?->courses()->current()->first();
    }

    /**
     * تُستدعى من mount() في الشاشات التي لا معنى لها قبل وجود معهد.
     */
    protected function requireInstitute(): void
    {
        if ($this->institute !== null) {
            return;
        }

        $this->redirect(
            Auth::user()?->can('institutes.manage') ? route('institutes.index') : route('dashboard'),
            navigate: true,
        );
    }
}
