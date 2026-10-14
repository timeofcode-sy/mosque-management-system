<?php

namespace App\Actions;

use App\Models\CustomField;
use App\Models\Institute;
use Illuminate\Support\Str;

/**
 * يحفظ واصفةً مخصّصة — من شاشة «الواصفات المخصّصة» في اللوحة ومن برنامج الإدارة.
 *
 * والخياراتُ تأتي نصّاً بسطرٍ لكل خيار (كما تُكتب في الاستمارة) أو قائمة، والمفتاحُ البرمجيُّ
 * يُشتقّ من الاسم إن تُرك.
 */
class SaveCustomField
{
    public const ENTITIES = [
        'student' => 'الطالب',
        'teacher' => 'الأستاذ',
        'circle' => 'الحلقة',
    ];

    /**
     * @param  array{entity: string, label: string, key?: ?string, type: string, options?: string|array<int, string>|null, group?: ?string, is_required?: bool, is_active?: bool, sort_order?: int}  $attributes
     */
    public function handle(Institute $institute, array $attributes, ?CustomField $existing = null): CustomField
    {
        $options = is_array($attributes['options'] ?? null)
            ? $attributes['options']
            : explode("\n", (string) ($attributes['options'] ?? ''));

        $options = collect($options)->map(fn ($line) => trim((string) $line))->filter()->values()->all();

        $payload = [
            'institute_id' => $institute->id,
            'entity' => $attributes['entity'],
            'label' => $attributes['label'],
            // المفتاحُ يبقى عند التعديل: القيمُ المخزَّنة معلَّقةٌ عليه، وتوليدُه من
            // العنوان من جديد يقطعها عن واصفتها. والعنوانُ العربيُّ قد لا يعطي slug.
            'key' => ($attributes['key'] ?? null)
                ?: $existing?->key
                ?: (Str::slug($attributes['label'], '_') ?: 'field_'.Str::lower(Str::random(6))),
            'type' => $attributes['type'],
            'options' => $options ?: null,
            'group' => ($attributes['group'] ?? null) ?: null,
            'is_required' => (bool) ($attributes['is_required'] ?? false),
            'is_active' => (bool) ($attributes['is_active'] ?? true),
            'sort_order' => (int) ($attributes['sort_order'] ?? 0),
        ];

        if ($existing !== null) {
            $existing->update($payload);

            return $existing->refresh();
        }

        return CustomField::create($payload);
    }
}
