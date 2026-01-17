<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\{BelongsTo, HasMany, BelongsToMany};

class Recipe extends Model
{
    protected $fillable = [
        'user_id','category_id',
        'title','description',
        'servings','prep_minutes','cook_minutes',
        'visibility',
        'status','approved_by','approved_at','rejection_reason',
        'rating_avg','rating_count',
        'cover_image',
    ];

    protected $casts = [
        'approved_at' => 'datetime',
        'rating_avg' => 'decimal:2',
    ];

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(RecipeCategory::class, 'category_id');
    }

    public function tags(): BelongsToMany
    {
        return $this->belongsToMany(RecipeTag::class, 'recipe_tag', 'recipe_id', 'recipe_tag_id');
    }

    public function ingredients(): HasMany
    {
        return $this->hasMany(RecipeIngredient::class)->orderBy('sort_order');
    }

    public function steps(): HasMany
    {
        return $this->hasMany(RecipeStep::class)->orderBy('sort_order');
    }

    public function comments(): HasMany
    {
        return $this->hasMany(RecipeComment::class)->latest();
    }

    public function reviews(): HasMany
    {
        return $this->hasMany(RecipeReview::class);
    }

    public function likes(): HasMany
    {
        return $this->hasMany(RecipeLike::class);
    }

    public function bookmarks(): HasMany
    {
        return $this->hasMany(RecipeBookmark::class);
    }
}
