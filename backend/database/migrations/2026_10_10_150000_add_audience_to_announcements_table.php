<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * `audience`: لمن يُوجَّه الإعلان — طلاب وأولياء أمور وأساتذة، فئةٌ أو أكثر. الإعلاناتُ القائمة كانت للطلاب
     * وحدهم فتُملأ بـ ["students"].
     *
     * وتُصحَّح معها `scope_ids`: شاشةُ الإعلانات كانت تخزّن معرّفات الحلقات **نصوصاً** ("3") والبحثُ بالرقم،
     * فلا يصل إعلانُ حلقةٍ محدّدة أحداً.
     */
    public function up(): void
    {
        Schema::table('announcements', function (Blueprint $table) {
            $table->json('audience')->nullable()->after('scope_ids');
        });

        DB::table('announcements')->orderBy('id')->each(function (object $row): void {
            $ids = $row->scope_ids === null ? null : json_decode($row->scope_ids, true);

            DB::table('announcements')->where('id', $row->id)->update([
                'audience' => json_encode(['students']),
                'scope_ids' => is_array($ids) ? json_encode(array_values(array_map('intval', $ids))) : $row->scope_ids,
            ]);
        });
    }

    public function down(): void
    {
        Schema::table('announcements', function (Blueprint $table) {
            $table->dropColumn('audience');
        });
    }
};
