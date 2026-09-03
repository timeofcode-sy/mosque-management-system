<?php

namespace App\Concerns;

use App\Models\Course;
use App\Models\Institute;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Session;
use Livewire\Attributes\Computed;
use Spatie\Permission\PermissionRegistrar;

/**
 * يمنح مكوّنات اللوحة المعهدَ العامل والدورةَ الجارية.
 *
 * المعهد يُحسم مرّة واحدة ويُثبَّت في الجلسة، ويُضبط معه مفتاح الفريق في Spatie
 * حتى تعمل فحوص الصلاحيات المرتبطة بمعهد دون إعداد يدوي في كل مكوّن.
 * يعود بـ null قبل إنشاء أول معهد — الشاشات تتعامل مع ذلك بحالة فارغة أو تحويل.
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
        $institute = $this->resolveInstitute();

        if ($institute === null) {
            return null;
        }

        Session::put('institute_id', $institute->id);

        App::make(PermissionRegistrar::class)->setPermissionsTeamId($institute->id);

        return $institute;
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
        if ($this->institute === null) {
            $this->redirect(route('institute.edit'), navigate: true);
        }
    }

    private function resolveInstitute(): ?Institute
    {
        $fromSession = Session::get('institute_id')
            ? Institute::find(Session::get('institute_id'))
            : null;

        return $fromSession
            ?? $this->instituteOfCurrentUser()
            ?? Institute::query()->where('is_active', true)->orderBy('id')->first();
    }

    private function instituteOfCurrentUser(): ?Institute
    {
        $user = Auth::user();

        if ($user === null) {
            return null;
        }

        $instituteId = $user->teacher?->institute_id
            ?? $user->guardian?->institute_id
            ?? $user->student?->institute_id;

        return $instituteId ? Institute::find($instituteId) : null;
    }
}
