<?php

use App\Enums\ProgressStatus;
use App\Models\StudentCurriculumProgress;
use Illuminate\Database\Migrations\Migration;

/**
 * الجزء القرآني لا «متقَن» فيه — «محفوظ» يكفي، والسبر يقيس الإتقان بعلامته.
 *
 * فالجزء «المتقَن» يصير «محفوظاً»، والمحفوظ تُضبط نسبته 100 (كانت استمارة التسجيل
 * تعلّمه محفوظاً بنسبة صفر). الكتابة بالنموذج لا بتحديثٍ جماعي، كي يُسجَّل التغيير في
 * change_log فيصل التطبيقات.
 */
return new class extends Migration
{
    public function up(): void
    {
        StudentCurriculumProgress::query()
            ->whereIn('status', [ProgressStatus::Memorized, ProgressStatus::Mastered])
            ->whereHas('curriculumItem', fn ($query) => $query->whereNotNull('meta->juz'))
            ->with('curriculumItem.curriculum')
            ->lazyById()
            ->each(function (StudentCurriculumProgress $progress): void {
                if ($progress->curriculumItem?->juz() === null) {
                    return;
                }

                $progress->update(['status' => ProgressStatus::Memorized, 'percent' => 100]);
            });
    }

    public function down(): void
    {
        // لا رجعة: لا يُعرف أيّ الأجزاء كان «متقَناً» قبل الدمج.
    }
};
