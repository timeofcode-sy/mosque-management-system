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
            // 🔄 م.7.1: **يومُ الحضور** لا لحظةُ تسجيله. recorded_at وحده كان يكفي
            // شاشةَ الأستاذ لأنها تفتح يوماً بعينه فتعرفه مسبقاً، ولا يكفي سجلّاً
            // يُقرأ يوماً بيوم كسجلّ ولي الأمر والطالب: أستاذٌ يصحّح جلسةَ أمس
            // اليوم يكتب recorded_at اليومَ، فيقع السجلُّ في اليوم الخطأ عند من
            // يقرؤه ([API.md §3.6](../../../../docs/API.md)).
            //
            // whenLoaded لا قراءةٌ مباشرة: المورد يُستعمل في قوائمَ طويلة،
            // والعلاقةُ غيرُ محمّلةٍ تعني n+1 صامتاً بعدد السجلّات.
            'session_date' => $this->whenLoaded(
                'attendanceSession',
                fn () => $this->attendanceSession->session_date->toDateString(),
            ),
        ];
    }
}
