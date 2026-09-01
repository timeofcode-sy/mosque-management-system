<?php

namespace App\Actions;

use App\Models\Curriculum;
use App\Models\CurriculumItem;

/**
 * حفظ بند منهج مع ضمان رمزٍ فريد داخل المنهج.
 *
 * الرمز إلزامي وفريد في المخطط (unique على curriculum_id + code)، وأكثر المشرفين
 * يتركه فارغاً — فيُشتقّ من الترتيب، ويُزاد لاحقةً عند التصادم بدل أن يفشل الحفظ.
 */
class SaveCurriculumItem
{
    /**
     * @param  array{name: string, code?: string|null, sort_order?: int}  $attributes
     */
    public function handle(Curriculum $curriculum, array $attributes, ?int $editingId = null): CurriculumItem
    {
        $sortOrder = $attributes['sort_order'] ?? $curriculum->items()->count();

        return CurriculumItem::updateOrCreate(
            ['id' => $editingId],
            [
                'curriculum_id' => $curriculum->id,
                'name' => $attributes['name'],
                'sort_order' => $sortOrder,
                'code' => blank($attributes['code'] ?? null)
                    ? $this->uniqueCode($curriculum, $sortOrder, $editingId)
                    : $attributes['code'],
            ],
        );
    }

    private function uniqueCode(Curriculum $curriculum, int $sortOrder, ?int $editingId): string
    {
        $base = 'item-'.($sortOrder + 1);
        $code = $base;
        $suffix = 1;

        while ($this->taken($curriculum, $code, $editingId)) {
            $code = $base.'-'.(++$suffix);
        }

        return $code;
    }

    private function taken(Curriculum $curriculum, string $code, ?int $editingId): bool
    {
        return CurriculumItem::query()
            ->where('curriculum_id', $curriculum->id)
            ->where('code', $code)
            ->whereKeyNot($editingId ?? 0)
            ->exists();
    }
}
