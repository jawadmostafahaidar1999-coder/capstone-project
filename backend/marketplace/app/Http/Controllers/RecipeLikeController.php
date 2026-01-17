<?php

namespace App\Http\Controllers;

use App\Models\Recipe;
use App\Models\RecipeLike;

class RecipeLikeController extends Controller
{
    public function store(Recipe $recipe)
    {
        $userId = auth()->id();

        if ($recipe->status !== 'approved' || $recipe->visibility !== 'public') {
            abort(404);
        }

        RecipeLike::firstOrCreate([
            'recipe_id' => $recipe->id,
            'user_id' => $userId,
        ]);

        return response()->json([
            'is_liked' => true,
            'likes_count' => $recipe->likes()->count(),
        ]);
    }

    public function destroy(Recipe $recipe)
    {
        $userId = auth()->id();

        RecipeLike::where('recipe_id', $recipe->id)
            ->where('user_id', $userId)
            ->delete();

        return response()->json([
            'is_liked' => false,
            'likes_count' => $recipe->likes()->count(),
        ]);
    }
}
