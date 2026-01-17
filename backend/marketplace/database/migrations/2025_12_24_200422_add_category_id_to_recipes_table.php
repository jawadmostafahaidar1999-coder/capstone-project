<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('recipes', function (Blueprint $table) {
            if (!Schema::hasColumn('recipes', 'category_id')) {
                $table->foreignId('category_id')
                    ->nullable()
                    ->constrained('recipe_categories')
                    ->nullOnDelete()
                    ->after('visibility'); // change position if needed
            }
        });
    }

    public function down(): void
    {
        Schema::table('recipes', function (Blueprint $table) {
            if (Schema::hasColumn('recipes', 'category_id')) {
                $table->dropConstrainedForeignId('category_id');
            }
        });
    }
};
