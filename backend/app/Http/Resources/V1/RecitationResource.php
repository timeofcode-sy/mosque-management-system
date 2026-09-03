<?php

namespace App\Http\Resources\V1;

use App\Models\MemorizationLog;
use App\Support\Quran;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin MemorizationLog */
class RecitationResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'uuid' => $this->uuid,
            'student_uuid' => $this->student?->uuid,
            'session_uuid' => $this->attendanceSession?->uuid,
            'date' => $this->date?->toDateString(),
            'type' => $this->type,
            'grade' => $this->grade,
            'juz' => $this->juz,
            'from_surah' => $this->from_surah,
            'from_surah_name' => $this->from_surah === null ? null : Quran::name((int) $this->from_surah),
            'from_ayah' => $this->from_ayah,
            'to_surah' => $this->to_surah,
            'to_surah_name' => $this->to_surah === null ? null : Quran::name((int) $this->to_surah),
            'to_ayah' => $this->to_ayah,
            'lines' => (float) $this->lines,
            'new_lines' => (float) $this->new_lines,
            'points' => (float) $this->points,
            'notes' => $this->notes,
        ];
    }
}
