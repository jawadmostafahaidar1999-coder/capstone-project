<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('recipe_tag', function (Blueprint $table) {
            $table->foreignId('recipe_id')->constrained('recipes')->cascadeOnDelete();
            $table->foreignId('recipe_tag_id')->constrained('recipe_tags')->cascadeOnDelete();

            $table->primary(['recipe_id', 'recipe_tag_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('recipe_tag');
    }
};
