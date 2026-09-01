<?php

namespace App\Concerns;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

/**
 * يمنح النموذج معرّفاً عالمياً (UUID) يولّده العميل أوف-لاين أو الخادم عند الإنشاء.
 * هذا المعرّف هو مفتاح المزامنة بين الخادم وتطبيقات فلاتر.
 */
trait HasUuid
{
    protected static function bootHasUuid(): void
    {
        static::creating(function (Model $model): void {
            if (blank($model->getAttribute('uuid'))) {
                $model->setAttribute('uuid', (string) Str::uuid7());
            }
        });
    }

    public function getRouteKeyName(): string
    {
        return 'uuid';
    }
}
