<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreRecipeCommentRequest;
use App\Models\Recipe;
use App\Models\RecipeComment;

class RecipeCommentController extends Controller
{
    public function index(Recipe $recipe)
    {
        if ($recipe->status !== 'approved' || $recipe->visibility !== 'public') {
            abort(404);
        }

        $comments = RecipeComment::query()
            ->where('recipe_id', $recipe->id)
            ->whereNull('parent_id')
            ->with(['user', 'replies.user'])
            ->latest()
            ->paginate(20);

        return response()->json($comments);
    }

    public function store(StoreRecipeCommentRequest $request, Recipe $recipe)
    {
        if ($recipe->status !== 'approved' || $recipe->visibility !== 'public') {
            abort(404);
        }

        $data = $request->validated();

        if (!empty($data['parent_id'])) {
            $parent = RecipeComment::findOrFail($data['parent_id']);
            if ($parent->recipe_id !== $recipe->id) {
                return response()->json(['message' => 'Invalid parent comment.'], 422);
            }
        }

        $comment = RecipeComment::create([
            'recipe_id' => $recipe->id,
            'user_id' => $request->user()->id,
            'parent_id' => $data['parent_id'] ?? null,
            'body' => $data['body'],
        ]);

        $comment->load('user');

        return response()->json(['data' => $comment], 201);
    }

    public function destroy(RecipeComment $comment)
    {
        $user = auth()->user();
        $isAdmin = (($user->role ?? null) === 'admin');

        if (!$isAdmin && $comment->user_id !== $user->id) {
            abort(403);
        }

        $comment->delete();

        return response()->json(['message' => 'Deleted']);
    }
}
