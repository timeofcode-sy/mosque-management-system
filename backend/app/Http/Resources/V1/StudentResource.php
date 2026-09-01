<?php

namespace App\Http\Resources\V1;

use App\Models\Student;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Student */
class StudentResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'registration_no' => $this->registration_no,
            'full_name' => $this->full_name,
            'photo_path' => $this->photo_path,
            'status' => $this->status,
        ];
    }
}
