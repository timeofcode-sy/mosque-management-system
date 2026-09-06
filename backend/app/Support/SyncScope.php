<?php

namespace App\Support;

use App\Contracts\Syncable;
use Illuminate\Database\Eloquent\Model;

/**
 * حسمُ معهد صفٍّ عبر أبيه، محفوظاً في الذاكرة.
 *
 * الحفظ ليس ترفاً: بذرُ جلسةٍ فيها عشرون طالباً يسأل عن **نفس** الجلسة عشرين مرة،
 * وكل سؤال يصعد سلسلة الآباء إلى المعهد. بلا حفظٍ يصير تسجيلُ التغيير أغلى من
 * الكتابة التي يسجّلها.
 *
 * الذاكرة تُمسح مع كل نسخة تطبيق (منشئ SyncRecorder) — أي مع كل طلب إنتاجاً ومع كل
 * اختبار تطويراً؛ فلا يبقى معرّفٌ من قاعدةٍ أُعيد بناؤها.
 */
class SyncScope
{
    /** @var array<string, int|null> */
    private static array $memo = [];

    /**
     * @param  class-string<Model&Syncable>  $parent
     */
    public static function via(string $parent, int|string|null $parentId): ?int
    {
        if ($parentId === null) {
            return null;
        }

        $key = $parent.':'.$parentId;

        if (array_key_exists($key, self::$memo)) {
            return self::$memo[$key];
        }

        // withoutGlobalScopes: الأب المحذوف حذفاً ليّناً ما زال يحمل معهده، وأبناؤه
        // الذين يُحذفون بعده يحتاجون معهده ليصل حذفُهم إلى العملاء.
        $model = $parent::query()->withoutGlobalScopes()->find($parentId);

        return self::$memo[$key] = $model?->syncInstituteId();
    }

    public static function flush(): void
    {
        self::$memo = [];
    }
}
