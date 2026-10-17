<?php

namespace App\Console\Commands;

use App\Models\Guardian;
use App\Models\Institute;
use App\Models\Student;
use App\Models\Teacher;
use App\Models\User;
use App\Support\Credentials;
use Illuminate\Console\Command;

/**
 * يُصدر كلمات المرور لحسابات معهدٍ وُلّدت بلا كلمات (ضمُّ معهدٍ بـ institute:import).
 *
 * يخصّ الأستاذ وولي الأمر والطالب وحدهم، ومن لا نسخةَ مقروءةً لكلمته فقط: هؤلاء لا
 * يبدّلون كلماتهم بأنفسهم، فغياب النسخة عندهم يعني أن كلمةً لم تُصدَر — ومن صدرت له
 * لا يُمسّ. الكلمة الجديدة ثمانية أرقام كما يولّدها GenerateAccount، وتظهر في شاشة
 * «بيانات الدخول» وبطاقاتها المطبوعة.
 */
class IssuePasswordsCommand extends Command
{
    protected $signature = 'accounts:issue-passwords
                            {institute : معرّف المعهد أو اسمه}
                            {--dry-run : يعدّ الحسابات بلا كتابة}';

    protected $description = 'يُصدر كلمات مرور لحسابات الأساتذة وأولياء الأمور والطلاب التي لا كلمة لها';

    public function handle(): int
    {
        $value = (string) $this->argument('institute');
        $institute = Institute::query()->whereKey(ctype_digit($value) ? (int) $value : 0)->orWhere('name', $value)->first();

        if ($institute === null) {
            $this->error("لا معهد: {$value}");

            return self::FAILURE;
        }

        $ids = collect([Teacher::class, Guardian::class, Student::class])
            ->flatMap(fn (string $model) => $model::query()->where('institute_id', $institute->id)->whereNotNull('user_id')->pluck('user_id'))
            ->unique();

        $users = User::query()->whereIn('id', $ids)->whereNull('generated_password')->get();

        if ($this->option('dry-run')) {
            $this->info("{$users->count()} حساباً بلا كلمة مرور في «{$institute->name}».");

            return self::SUCCESS;
        }

        foreach ($users as $user) {
            $password = Credentials::password();
            $user->forceFill(['password' => $password, 'generated_password' => $password])->save();
        }

        $this->info("أُصدرت {$users->count()} كلمة مرور في «{$institute->name}» — تظهر في «بيانات الدخول».");

        return self::SUCCESS;
    }
}
