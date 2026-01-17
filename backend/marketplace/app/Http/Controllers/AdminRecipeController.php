<?php

namespace App\Http\Controllers;

use App\Http\Requests\AdminRejectRecipeRequest;
use App\Http\Resources\RecipeResource;
use App\Models\Recipe;

class AdminRecipeController extends Controller
{
    public function pending()
    {
        $recipes = Recipe::query()
            ->where('status', 'pending')
            ->with(['author.vendor','category','tags'])
            ->withCount(['likes','bookmarks'])
            ->latest()
            ->paginate(20);

        return RecipeResource::collection($recipes);
    }

    public function approve(Recipe $recipe)
    {
        $recipe->update([
            'status' => 'approved',
            'approved_by' => auth()->id(),
            'approved_at' => now(),
            'rejection_reason' => null,
        ]);

        $recipe->load(['author.vendor','category','tags'])
              ->loadCount(['likes','bookmarks']);

        $recipe->setAttribute('is_liked', false);
        $recipe->setAttribute('is_bookmarked', false);

        return response()->json([
            'message' => 'Approved',
            'data' => new RecipeResource($recipe),
        ]);
    }

    public function reject(AdminRejectRecipeRequest $request, Recipe $recipe)
    {
        $recipe->update([
            'status' => 'rejected',
            'approved_by' => auth()->id(),
            'approved_at' => now(),
            'rejection_reason' => $request->validated()['rejection_reason'],
        ]);

        return response()->json(['message' => 'Rejected']);
    }
}
