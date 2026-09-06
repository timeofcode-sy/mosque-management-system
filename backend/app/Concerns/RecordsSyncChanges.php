<?php

namespace App\Concerns;

use App\Enums\SyncOperation;
use App\Support\SyncRecorder;
use Illuminate\Database\Eloquent\Model;

/**
 * يجعل كلَّ كتابةٍ على النموذج صفّاً في change_log يقرؤه العملاء عبر sync/pull.
 *
 * يُستعمل مع App\Contracts\Syncable ولا يُغني عنها: الواجهة تحسم المعهد، وهذا يوصل
 * الأحداث. وفصلُهما مقصود ليبقى «هل يُزامَن هذا الجدول؟» سؤالاً يُجاب في النموذج
 * نفسه لا في قائمةٍ بعيدة تُنسى عند إضافة جدول.
 *
 * الحذف الليّن يُسجَّل delete: العميل يزيل الصفّ من مخزنه، ورجوعُه بـ restore يصله
 * create بحمولته كاملة. أمّا الحذفُ المتسلسل في قاعدة البيانات (حذفُ جلسةٍ يجرّ
 * حضورَها) فلا يُطلق أحداث Eloquent ⇒ لا يُسجَّل، وهو قيدٌ مقبول لأن حذف الأصل نفسه
 * يصل العميلَ فيسقط ما تحته.
 */
trait RecordsSyncChanges
{
    protected static function bootRecordsSyncChanges(): void
    {
        static::created(fn (Model $model) => app(SyncRecorder::class)->record($model, SyncOperation::Create));
        static::updated(fn (Model $model) => app(SyncRecorder::class)->record($model, SyncOperation::Update));
        static::deleted(fn (Model $model) => app(SyncRecorder::class)->record($model, SyncOperation::Delete));
        // registerModelEvent لا restored(): الأخيرة تأتي مع SoftDeletes وحدها،
        // وبعضُ جداول الربط لا تستعملها فيسقط النموذج كلُّه بخطأ استدعاءٍ لدالّة معدومة.
        static::registerModelEvent('restored', fn (Model $model) => app(SyncRecorder::class)->record($model, SyncOperation::Create));
    }
}
