<?php

namespace App\Observers;

use App\Actions\GenerateAccount;
use Illuminate\Database\Eloquent\Model;

/**
 * السلوك المشترك لمراقبي الأستاذ وولي الأمر والطالب: حسابٌ يولَّد مع السجلّ،
 * ويُقفل ويُفتح تبعاً لحالته.
 *
 * ثلاثة مراقبين لا واحد لأن #[ObservedBy] يلزمه صفٌّ لكل نموذج، والمشترك بينها
 * كلُّ ما عدا الصفّ نفسه.
 */
trait GeneratesAccount
{
    public function __construct(private readonly GenerateAccount $accounts) {}

    public function created(Model $record): void
    {
        $this->accounts->handle($record);
    }

    /**
     * الحالة وحدها تعني الحساب — تغيير الاسم أو الهاتف لا يمسّه.
     */
    public function updated(Model $record): void
    {
        if ($record->wasChanged('status')) {
            $this->accounts->syncActivation($record);
        }
    }

    /**
     * الحذف اللين يُقفل الدخول ولا يحذف الحساب: سجلّاتُ الحضور والتلاوة مربوطة به،
     * ورجوعُ السجلّ يعيد صاحبَه بالاسم وكلمة المرور نفسيهما.
     */
    public function deleted(Model $record): void
    {
        $this->accounts->syncActivation($record);
    }

    public function restored(Model $record): void
    {
        $this->accounts->handle($record);
        $this->accounts->syncActivation($record);
    }
}
