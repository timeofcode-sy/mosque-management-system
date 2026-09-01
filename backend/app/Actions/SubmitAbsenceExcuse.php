<?php

namespace App\Actions;

use App\Enums\ExcuseStatus;
use App\Models\AbsenceExcuse;
use App\Models\Student;
use App\Models\User;

/**
 * تقديم إذن غياب مسبق. يقدّمه ولي الأمر من تطبيق الأهل (المرحلة 7)، ويقدّمه
 * المشرف نيابةً عنه من اللوحة حين يصل الإذن هاتفياً أو ورقياً.
 */
class SubmitAbsenceExcuse
{
    /**
     * @param  array{from_date: string, to_date: string, reason: string, attachment_path?: string|null}  $attributes
     */
    public function handle(Student $student, array $attributes, ?User $submittedBy = null): AbsenceExcuse
    {
        return AbsenceExcuse::create([
            'student_id' => $student->id,
            'from_date' => $attributes['from_date'],
            'to_date' => $attributes['to_date'],
            'reason' => $attributes['reason'],
            'attachment_path' => $attributes['attachment_path'] ?? null,
            'submitted_by' => $submittedBy?->id,
            'status' => ExcuseStatus::Pending,
        ]);
    }
}
