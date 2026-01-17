<?php

namespace App\Http\Controllers;

use App\Http\Resources\RecipeResource;
use App\Models\Recipe;
use Illuminate\Http\Request;

class RecipeTrendingController extends Controller
{
    public function week(Request $request)
    {
        $authId = auth()->id();
        $perPage = min(max((int) $request->query('per_page', 10), 1), 50);

        $query = Recipe::query()
            ->where('status', 'approved')
            ->where('visibility', 'public')
            ->with(['author.vendor','category','tags'])
            ->withCount(['likes','bookmarks'])
            ->withCount([
                'likes as likes_week_count' => fn($q) => $q->where('created_at', '>=', now()->subDays(7))
            ]);

        if ($authId) {
            $query->withExists([
                'likes as is_liked' => fn($q) => $q->where('user_id', $authId),
                'bookmarks as is_bookmarked' => fn($q) => $q->where('user_id', $authId),
            ]);
        } else {
            $query->select('recipes.*')
                  ->selectRaw('false as is_liked')
                  ->selectRaw('false as is_bookmarked');
        }

        $query->orderByDesc('likes_week_count')
              ->orderByDesc('created_at');

        return RecipeResource::collection($query->paginate($perPage));
    }
}
