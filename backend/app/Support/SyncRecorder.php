<?php

namespace App\Support;

use App\Actions\RecordChange;
use App\Contracts\Syncable;
use App\Enums\SyncOperation;
use App\Models\Institute;
use App\Models\User;
use Closure;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;

/**
 * سياقُ تسجيل التغييرات: من يكتب الآن، ومن أي جهاز، وتحت أي op_uuid.
 *
 * كان تسجيلُ التغيير قبل هذا الصنف استدعاءً يدوياً في SyncPush وحده، فكانت كتابات
 * اللوحة لا تصل أي عميل. صار أثراً بنيوياً: مراقب RecordsSyncChanges يستدعي record()
 * عند كل إنشاء أو تعديل أو حذف على نموذج ينفّذ Syncable، فيستوي مصدر الكتابة —
 * شاشةُ Livewire أو دفعةُ مزامنة أو أمرُ artisan.
 *
 * والسياق أحادي النسخة في الحاوية لأنه حالةُ الطلب لا حالةَ نموذج: SyncPush يضبطه مرّة
 * لكل عملية، والمراقب يقرؤه من حيث لا يملك تمرير وسيط.
 */
class SyncRecorder
{
    private bool $enabled = true;

    private ?User $actor = null;

    private ?string $deviceUuid = null;

    /** op_uuid ينتظر أوّل صفٍّ يستهلكه — انظر during(). */
    private ?string $pendingOpUuid = null;

    /** @var array<int, string> معرّف المعهد إلى uuid — نفس سبب الحفظ في SyncScope. */
    private array $instituteUuids = [];

    public function __construct(private readonly RecordChange $recordChange)
    {
        SyncScope::flush();
    }

    public function record(Model $model, SyncOperation $operation): void
    {
        if (! $this->enabled || ! $model instanceof Syncable) {
            return;
        }

        $scopeKey = $this->scopeKey($model->syncInstituteId());

        if ($scopeKey === null) {
            return;
        }

        $this->recordChange->handle(
            $model,
            $operation,
            $scopeKey,
            $this->actor ?? Auth::user(),
            $this->deviceUuid,
            $this->consumeOpUuid(),
        );
    }

    /**
     * تنفيذ عملية دفعٍ واحدة تحت سياقها — ويعود true إن استهلك صفٌّ فعليٌّ op_uuid.
     *
     * منعُ التكرار في sync/push قائمٌ على وجود op_uuid في change_log؛ فلو لم تغيّر
     * العملية شيئاً (إعادةُ فتح جلسةٍ قائمة، أو تفقّدٌ بنفس القيم) لم يُكتب صفّ، ولوجب
     * على المستدعي أن يكتب صفّاً دالاً بنفسه — وإلا أُعيد تطبيقُ العملية عند كل إرسال.
     */
    public function during(?User $actor, ?string $deviceUuid, ?string $opUuid, Closure $callback): bool
    {
        $previous = [$this->actor, $this->deviceUuid, $this->pendingOpUuid];

        $this->actor = $actor;
        $this->deviceUuid = $deviceUuid;
        $this->pendingOpUuid = $opUuid;

        try {
            $callback();

            return $opUuid !== null && $this->pendingOpUuid === null;
        } finally {
            [$this->actor, $this->deviceUuid, $this->pendingOpUuid] = $previous;
        }
    }

    /**
     * تعطيل التسجيل مؤقتاً — للبذور وحدها، **وللسرعة وحدها**.
     *
     * ⚠️ ما يُكتَم هنا لا يراه عميلٌ أبداً. `SyncPull` يقرأ change_log وحده ولا يمسّ
     * جداول الدومين، فـ`since=0` ليس «لقطةَ الحالة» بل «التيّارَ من أوّله». فمن عطّل
     * التسجيل وجب عليه أن يُتبعه بـ`sync:backfill-change-log` — وهو ما يفعله
     * `DatabaseSeeder` — وإلا خرجت قاعدةٌ عامرةٌ وتطبيقاتٌ فارغة.
     *
     * @template TReturn
     *
     * @param  Closure(): TReturn  $callback
     * @return TReturn
     */
    public function without(Closure $callback): mixed
    {
        $previous = $this->enabled;
        $this->enabled = false;

        try {
            return $callback();
        } finally {
            $this->enabled = $previous;
        }
    }

    /**
     * تنفيذُ كتابةٍ ليست ملاحظةَ جهاز — الصفوف التي تُزرع تلقائياً عند فتح جلسة مثلاً.
     *
     * تُسجَّل في change_log كاملةً (العميل يحتاجها) لكن بلا device_uuid، فيميّزها حلُّ
     * التعارض عن قيمةٍ رآها أستاذٌ بعينه على جهازه — ولا يُهدر تفقّدٌ حقيقي دفاعاً عن
     * قيمةٍ افتراضية لم يقلها أحد.
     *
     * @template TReturn
     *
     * @param  Closure(): TReturn  $callback
     * @return TReturn
     */
    public function withoutDevice(Closure $callback): mixed
    {
        $previous = $this->deviceUuid;
        $this->deviceUuid = null;

        try {
            return $callback();
        } finally {
            $this->deviceUuid = $previous;
        }
    }

    private function consumeOpUuid(): ?string
    {
        $opUuid = $this->pendingOpUuid;
        $this->pendingOpUuid = null;

        return $opUuid;
    }

    private function scopeKey(?int $instituteId): ?string
    {
        if ($instituteId === null) {
            return null;
        }

        $uuid = $this->instituteUuids[$instituteId]
            ??= (string) Institute::query()->whereKey($instituteId)->value('uuid');

        return $uuid === '' ? null : 'institute:'.$uuid;
    }
}
