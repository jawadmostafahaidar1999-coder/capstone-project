<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('recipes', function (Blueprint $table) {
            $table->id();

            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('category_id')->nullable()->constrained('recipe_categories')->nullOnDelete();

            $table->string('title');
            $table->text('description')->nullable();

            $table->unsignedSmallInteger('servings')->nullable();
            $table->unsignedSmallInteger('prep_minutes')->nullable();
            $table->unsignedSmallInteger('cook_minutes')->nullable();

            // public/private (you can later add "unlisted" if you want)
            $table->string('visibility')->default('public'); // public|private

            // admin approval workflow
            $table->string('status')->default('pending'); // pending|approved|rejected
            $table->foreignId('approved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('approved_at')->nullable();
            $table->text('rejection_reason')->nullable();

            // rating summary (fast sorting by rating)
            $table->decimal('rating_avg', 3, 2)->default(0); // 0.00 - 5.00
            $table->unsignedInteger('rating_count')->default(0);

            // optional cover image
            $table->string('cover_image')->nullable();

            $table->timestamps();

            $table->index(['status', 'created_at']);
            $table->index(['category_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('recipes');
    }
};
