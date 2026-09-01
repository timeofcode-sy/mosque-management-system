<?php

namespace App\Http\Resources\V1;

use App\Models\ChangeLog;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin ChangeLog */
class ChangeLogResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'server_seq' => $this->id,
            'table_name' => $this->table_name,
            'row_uuid' => $this->row_uuid,
            'operation' => $this->operation,
            'payload' => $this->payload,
            'created_at' => $this->created_at,
        ];
    }
}
