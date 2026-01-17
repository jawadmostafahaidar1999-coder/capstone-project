<?php

namespace App\Http\Controllers;

use App\Models\Recipe;
use App\Models\RecipeBookmark;

class RecipeBookmarkController extends Controller
{
    public function store(Recipe $recipe)
    {
        $userId = auth()->id();

        if ($recipe->status !== 'approved' || $recipe->visibility !== 'public') {
            abort(404);
        }

        RecipeBookmark::firstOrCreate([
            'recipe_id' => $recipe->id,
            'user_id' => $userId,
        ]);

        return response()->json([
            'is_bookmarked' => true,
            'bookmarks_count' => $recipe->bookmarks()->count(),
        ]);
    }

    public function destroy(Recipe $recipe)
    {
        $userId = auth()->id();

        RecipeBookmark::where('recipe_id', $recipe->id)
            ->where('user_id', $userId)
            ->delete();

        return response()->json([
            'is_bookmarked' => false,
            'bookmarks_count' => $recipe->bookmarks()->count(),
        ]);
    }
}
