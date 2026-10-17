<?php

namespace App\Models;

use App\Enums\AppTarget;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

/**
 * آخرُ نسخةٍ أبلغ بها جهازٌ حين سأل عن التحديث — صفٌّ لكل جهازٍ وهدف.
 *
 * يُكتب من `GET /app-updates/check` ولو قبل الدخول، فيرى المبرمج كم جهازاً بلغه الإصدارُ
 * الأخير وكم بقي خلفه — وهو ما لا يقوله `sync_devices` لأن وليّ الأمر والطالب لا يزامنان.
 */
#[Fillable(['device_uuid', 'target', 'build_number', 'version', 'last_checked_at'])]
class AppInstall extends Model
{
    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'target' => AppTarget::class,
            'build_number' => 'integer',
            'last_checked_at' => 'datetime',
        ];
    }
}
