<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sync_conflicts', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();
            $table->string('table_name', 64);
            $table->uuid('row_uuid');
            $table->json('server_payload')->nullable();
            $table->json('client_payload')->nullable();
            $table->string('resolution', 24)->default('server_wins');
            $table->uuid('device_uuid')->nullable();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('resolved_at', 3)->nullable();
            $table->timestamps(3);

            $table->index(['table_name', 'row_uuid']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sync_conflicts');
    }
};
