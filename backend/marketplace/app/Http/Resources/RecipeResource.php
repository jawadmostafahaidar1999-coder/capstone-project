<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RecipeResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $author = $this->whenLoaded('author');

        $isVerifiedVendor = false;
        if ($author) {
            // assumes you already have $user->vendor relation with status field
            $isVerifiedVendor = ($author->role ?? null) === 'vendor'
                && optional($author->vendor)->status === 'approved';
        }

        return [
            'id' => $this->id,
            'title' => $this->title,
            'description' => $this->description,
            'servings' => $this->servings,
            'prep_minutes' => $this->prep_minutes,
            'cook_minutes' => $this->cook_minutes,
            'visibility' => $this->visibility,
            'status' => $this->status,
            'cover_image' => $this->cover_image,


            'category' => $this->whenLoaded('category', fn () => [
                'id' => $this->category->id,
                'name' => $this->category->name,
                'slug' => $this->category->slug,
            ]),

            'tags' => $this->whenLoaded('tags', fn () =>
                $this->tags->map(fn ($t) => ['id' => $t->id, 'name' => $t->name, 'slug' => $t->slug])
            ),

            'rating_avg' => (float) $this->rating_avg,
            'rating_count' => (int) $this->rating_count,

            'likes_count' => (int) ($this->likes_count ?? 0),
            'likes_week_count' => (int) ($this->likes_week_count ?? 0),
            'bookmarks_count' => (int) ($this->bookmarks_count ?? 0),

            'is_liked' => (bool) ($this->is_liked ?? false),
            'is_bookmarked' => (bool) ($this->is_bookmarked ?? false),

            'author' => $this->whenLoaded('author', fn () => [
                'id' => $author->id,
                'name' => $author->name,
                'role' => $author->role ?? 'user',
                'is_verified_vendor' => $isVerifiedVendor,
            ]),

            'created_at' => optional($this->created_at)->toISOString(),
        ];
    }
}
