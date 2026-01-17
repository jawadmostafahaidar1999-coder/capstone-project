<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\{BelongsTo, HasMany};

class RecipeComment extends Model
{
    protected $fillable = [
        'recipe_id',
        'user_id',
        'parent_id',
        'body',
    ];

    public function recipe(): BelongsTo
    {
        return $this->belongsTo(Recipe::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function parent(): BelongsTo
    {
        return $this->belongsTo(RecipeComment::class, 'parent_id');
    }

    public function replies(): HasMany
    {
        return $this->hasMany(RecipeComment::class, 'parent_id')->latest();
    }
}
