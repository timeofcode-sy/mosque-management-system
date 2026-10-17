<?php

use App\Models\Guardian;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * اسم ولي الأمر بقسمين: الاسم والكنية. full_name يبقى عموداً محفوظاً لأن القوائم وحسابات
 * الدخول ومطابقة الإخوة تقرؤه، لكنه صار يُركَّب منهما عند الحفظ (Guardian::booted).
 *
 * الردم: الأب يأخذ قسميه من الطالب (اسم الأب والكنية) إن طابقا اسمه المحفوظ، وما سواه
 * يُقسم على أول فراغ — الكلمة الأولى اسم والباقي كنية.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('guardians', function (Blueprint $table) {
            $table->string('first_name')->nullable()->after('full_name');
            $table->string('family_name')->nullable()->after('first_name');
        });

        $fathers = DB::table('guardian_student')
            ->join('students', 'students.id', '=', 'guardian_student.student_id')
            ->where('guardian_student.relation', 'father')
            ->get(['guardian_student.guardian_id', 'students.father_name', 'students.family_name'])
            ->groupBy('guardian_id');

        DB::table('guardians')->orderBy('id')->each(function (object $guardian) use ($fathers): void {
            $fullName = Guardian::composeName($guardian->full_name);

            $parts = collect($fathers->get($guardian->id, []))
                ->map(fn (object $row) => [trim($row->father_name), trim($row->family_name)])
                ->first(fn (array $parts) => Guardian::composeName(...$parts) === $fullName)
                ?? Guardian::splitName($fullName);

            DB::table('guardians')->where('id', $guardian->id)->update([
                'first_name' => $parts[0],
                'family_name' => $parts[1],
            ]);
        });
    }

    public function down(): void
    {
        Schema::table('guardians', function (Blueprint $table) {
            $table->dropColumn(['first_name', 'family_name']);
        });
    }
};
