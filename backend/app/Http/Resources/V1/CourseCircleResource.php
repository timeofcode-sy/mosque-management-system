<?php

namespace App\Http\Resources\V1;

use App\Models\CourseCircle;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin CourseCircle */
class CourseCircleResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'circle_name' => $this->circle?->name,
            'shift_name' => $this->shift?->name,
            'room' => $this->room,
            'capacity' => $this->capacity,
            'status' => $this->status,
            'students_count' => $this->whenCounted('activeEnrollments'),
        ];
    }
}
