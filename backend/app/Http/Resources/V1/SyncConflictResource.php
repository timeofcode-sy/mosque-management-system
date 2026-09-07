<?php

namespace App\Http\Resources\V1;

use App\Models\SyncConflict;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin SyncConflict */
class SyncConflictResource extends JsonResource
{
    /**
     * القيمتان المتنازعتان كاملتين لا ملخّصاً: شاشةُ الحكم في الديسكتوب تعرضهما
     * جنباً إلى جنب، وأيُّ ترشيحٍ هنا يجعل صاحبَ القرار يقرّر على نصف الصورة.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'table_name' => $this->table_name,
            'row_uuid' => $this->row_uuid,
            'server_payload' => $this->server_payload,
            'client_payload' => $this->client_payload,
            'resolution' => $this->resolution,
            'device_uuid' => $this->device_uuid,
            'reviewed_by' => $this->whenLoaded('reviewedBy', fn () => $this->reviewedBy?->name),
            'resolved_at' => $this->resolved_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
