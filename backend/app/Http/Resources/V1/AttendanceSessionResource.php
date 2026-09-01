<?php

namespace App\Http\Resources\V1;

use App\Models\AttendanceSession;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin AttendanceSession */
class AttendanceSessionResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'course_circle_uuid' => $this->courseCircle?->uuid,
            'session_date' => $this->session_date,
            'status' => $this->status,
            'editable' => $this->isEditable(),
            'completed_at' => $this->completed_at,
            'attendances' => AttendanceResource::collection($this->whenLoaded('attendances')),
        ];
    }
}
