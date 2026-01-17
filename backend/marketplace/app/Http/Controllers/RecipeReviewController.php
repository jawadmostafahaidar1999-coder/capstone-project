<?php

namespace App\Http\Controllers;

use App\Http\Requests\UpsertRecipeReviewRequest;
use App\Models\Recipe;
use App\Models\RecipeReview;
use App\Notifications\RecipeReviewedNotification;

class RecipeReviewController extends Controller
{

    public function index(Recipe $recipe)
    {
        if ($recipe->status !== 'approved' || $recipe->visibility !== 'public') {
            abort(404);
        }

        $reviews = $recipe->reviews()
            ->with('user:id,name,role')
            ->latest()
            ->paginate(20);

        return response()->json($reviews);
    }
    public function upsert(UpsertRecipeReviewRequest $request, Recipe $recipe)
    {
        if ($recipe->status !== 'approved' || $recipe->visibility !== 'public') {
            abort(404);
        }

        $userId = $request->user()->id;
        $data = $request->validated();

        RecipeReview::updateOrCreate(
            ['recipe_id' => $recipe->id, 'user_id' => $userId],
            ['rating' => $data['rating'], 'body' => $data['body'] ?? null]
        );

        $isNew = !RecipeReview::where('recipe_id', $recipe->id)
            ->where('user_id', $userId)
            ->exists();

        $review = RecipeReview::updateOrCreate(
            ['recipe_id' => $recipe->id, 'user_id' => $userId],
            ['rating' => $data['rating'], 'body' => $data['body'] ?? null]
        );

        $recipe->loadMissing('author');
        $author = $recipe->author;

        if ($isNew && $author && $author->id !== $userId) {
            $author->notify(new RecipeReviewedNotification($review, $recipe, $request->user()));
        }

        $this->recalculateRating($recipe);

        $fresh = $recipe->fresh();
        return response()->json([
            'message' => 'Review saved.',
            'rating_avg' => (float) $fresh->rating_avg,
            'rating_count' => (int) $fresh->rating_count,
        ]);

    }

    public function destroyMy(Recipe $recipe)
    {
        $userId = auth()->id();

        RecipeReview::where('recipe_id', $recipe->id)
            ->where('user_id', $userId)
            ->delete();

        $this->recalculateRating($recipe);

        $fresh = $recipe->fresh();
        return response()->json([
            'message' => 'Review deleted.',
            'rating_avg' => (float) $fresh->rating_avg,
            'rating_count' => (int) $fresh->rating_count,
        ]);
    }

    private function recalculateRating(Recipe $recipe): void
    {
        $stats = $recipe->reviews()
            ->selectRaw('COUNT(*) as cnt, COALESCE(AVG(rating),0) as avg_rating')
            ->first();

        $recipe->update([
            'rating_count' => (int) $stats->cnt,
            'rating_avg' => round((float) $stats->avg_rating, 2),
        ]);
    }
}
