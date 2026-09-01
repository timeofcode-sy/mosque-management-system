<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('change_log', function (Blueprint $table) {
            /** المعرّف التسلسلي هو نفسه server_seq الذي يستخدمه العملاء في sync/pull */
            $table->bigIncrements('id');
            $table->string('table_name', 64);
            $table->uuid('row_uuid');
            $table->string('operation', 16);
            $table->json('payload')->nullable();
            $table->string('scope_key', 96);
            $table->foreignId('actor_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->uuid('device_uuid')->nullable();
            $table->uuid('op_uuid')->nullable()->unique();
            $table->timestamp('created_at', 3);

            $table->index(['scope_key', 'id']);
            $table->index(['table_name', 'row_uuid']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('change_log');
    }
};
