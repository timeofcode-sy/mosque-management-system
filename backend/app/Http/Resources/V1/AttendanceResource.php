<?php

namespace App\Http\Resources\V1;

use App\Models\Attendance;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Attendance */
class AttendanceResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'student_uuid' => $this->student?->uuid,
            'student_name' => $this->student?->full_name,
            'status' => $this->status,
            'late_minutes' => $this->late_minutes,
            'note' => $this->note,
            'recorded_at' => $this->recorded_at,
        ];
    }
}
