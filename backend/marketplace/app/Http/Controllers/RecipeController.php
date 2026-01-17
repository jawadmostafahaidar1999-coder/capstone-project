<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreRecipeRequest;
use App\Http\Resources\RecipeDetailResource;
use App\Http\Resources\RecipeResource;
use App\Models\Recipe;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class RecipeController extends Controller
{
    public function index(Request $request)
    {
        // Works for guests + authenticated (Bearer token) even if route is public
        $authId = $request->user('sanctum')?->id;

        $q = trim((string) $request->query('q', ''));
        $categoryId = $request->integer('category_id') ?: null;

        // Accept tag_ids[0]=1&tag_ids[1]=2 OR tag_ids=1,2
        $tagIds = $request->input('tag_ids', []);
        if (is_string($tagIds)) {
            $tagIds = array_filter(explode(',', $tagIds));
        }
        $tagIds = array_values(array_filter(array_map('intval', (array) $tagIds)));

        $sort = (string) $request->query('sort', 'date'); // rating|date
        $order = strtolower((string) $request->query('order', 'desc')) === 'asc' ? 'asc' : 'desc';
        $perPage = min(max((int) $request->query('per_page', 10), 1), 50);

        $query = Recipe::query()
            ->where('status', 'approved')
            ->where('visibility', 'public')
            ->when($q !== '', function ($qq) use ($q) {
                $qq->where(function ($w) use ($q) {
                    $w->where('title', 'like', "%{$q}%")
                        ->orWhere('description', 'like', "%{$q}%");
                });
            })
            ->when($categoryId, fn($qq) => $qq->where('category_id', $categoryId))
            ->when(!empty($tagIds), function ($qq) use ($tagIds) {
                // "ANY of these tags" match
                $qq->whereHas('tags', fn($tq) => $tq->whereIn('recipe_tags.id', $tagIds));
            })
            ->with(['author.vendor', 'category', 'tags'])
            ->withCount(['likes', 'bookmarks']);

        if ($authId) {
            $query->withExists([
                'likes as is_liked' => fn($lq) => $lq->where('user_id', $authId),
                'bookmarks as is_bookmarked' => fn($bq) => $bq->where('user_id', $authId),
            ]);
        } else {
            // Safer than "false" across DBs
            $query->addSelect('recipes.*')
                ->selectRaw('0 as is_liked')
                ->selectRaw('0 as is_bookmarked');
        }

        if ($sort === 'rating') {
            $query->orderBy('rating_avg', $order)
                ->orderBy('created_at', 'desc'); // tie-breaker
        } else {
            $query->orderBy('created_at', $order);
        }

        return RecipeResource::collection($query->paginate($perPage));
    }

    public function show(Recipe $recipe)
    {
        $user = auth()->user();
        $authId = auth()->id();

        // Public can only see approved + public
        if ($recipe->status !== 'approved' || $recipe->visibility !== 'public') {
            $isOwner = $user && $recipe->user_id === $user->id;
            $isAdmin = $user && (($user->role ?? null) === 'admin');

            if (!($isOwner || $isAdmin)) {
                abort(404);
            }
        }

        $recipe->load(['author.vendor', 'category', 'tags', 'ingredients', 'steps'])
            ->loadCount(['likes', 'bookmarks']);

        if ($authId) {
            $recipe->loadExists([
                'likes as is_liked' => fn($q) => $q->where('user_id', $authId),
                'bookmarks as is_bookmarked' => fn($q) => $q->where('user_id', $authId),
            ]);
        } else {
            $recipe->setAttribute('is_liked', false);
            $recipe->setAttribute('is_bookmarked', false);
        }

        return new RecipeDetailResource($recipe);
    }

    public function store(StoreRecipeRequest $request)
    {
        $user = $request->user();
        $data = $request->validated();

        $recipe = DB::transaction(function () use ($data, $user) {
            $recipe = Recipe::create([
                'user_id' => $user->id,
                'category_id' => $data['category_id'] ?? null,
                'title' => $data['title'],
                'description' => $data['description'] ?? null,
                'servings' => $data['servings'] ?? null,
                'prep_minutes' => $data['prep_minutes'] ?? null,
                'cook_minutes' => $data['cook_minutes'] ?? null,
                'visibility' => $data['visibility'] ?? 'public',
                'cover_image' => $data['cover_image'] ?? null,
                'status' => 'pending', // approval workflow
            ]);

            if (!empty($data['tag_ids'])) {
                $recipe->tags()->sync($data['tag_ids']);
            }

            $recipe->ingredients()->createMany(
                collect($data['ingredients'])->values()->map(function ($ing, $i) {
                    return [
                        'name' => $ing['name'],
                        'quantity' => $ing['quantity'] ?? null,
                        'unit' => $ing['unit'] ?? null,
                        'note' => $ing['note'] ?? null,
                        'sort_order' => $i,
                    ];
                })->all()
            );

            $recipe->steps()->createMany(
                collect($data['steps'])->values()->map(function ($st, $i) {
                    return [
                        'text' => $st['text'],
                        'timer_minutes' => $st['timer_minutes'] ?? null,
                        'sort_order' => $i,
                    ];
                })->all()
            );

            return $recipe;
        });

        $recipe->load(['author.vendor', 'category', 'tags', 'ingredients', 'steps'])
            ->loadCount(['likes', 'bookmarks']);

        $recipe->setAttribute('is_liked', false);
        $recipe->setAttribute('is_bookmarked', false);

        return response()->json([
            'message' => 'Recipe submitted for admin approval.',
            'data' => new RecipeDetailResource($recipe),
        ], 201);
    }

    public function mine(Request $request)
    {
        $authId = $request->user()->id;
        $perPage = min(max((int) $request->query('per_page', 10), 1), 50);

        $recipes = Recipe::query()
            ->where('user_id', $authId)
            ->with(['author.vendor', 'category', 'tags'])
            ->withCount(['likes', 'bookmarks'])
            ->withExists([
                'likes as is_liked' => fn($q) => $q->where('user_id', $authId),
                'bookmarks as is_bookmarked' => fn($q) => $q->where('user_id', $authId),
            ])
            ->latest()
            ->paginate($perPage);

        return RecipeResource::collection($recipes);
    }

    public function bookmarks(Request $request)
    {
        $uid = $request->user()->id;
        $perPage = min(max((int) $request->query('per_page', 10), 1), 50);

        $recipes = Recipe::query()
            ->where('status', 'approved')
            ->where('visibility', 'public')
            ->whereHas('bookmarks', fn($q) => $q->where('user_id', $uid))
            ->with(['author.vendor', 'category', 'tags'])
            ->withCount(['likes', 'bookmarks'])
            ->withExists([
                'likes as is_liked' => fn($q) => $q->where('user_id', $uid),
                'bookmarks as is_bookmarked' => fn($q) => $q->where('user_id', $uid),
            ])
            ->latest()
            ->paginate($perPage);

        return RecipeResource::collection($recipes);
    }

    public function destroy(Recipe $recipe)
    {
        $user = request()->user();

        // Only owner (or admin if you want)
        if ($recipe->user_id !== $user->id && ($user->role ?? '') !== 'admin') {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        // Clean relations (safe even if you already have cascades)
        $recipe->tags()->detach();
        $recipe->ingredients()->delete();
        $recipe->steps()->delete();
        $recipe->comments()->delete();
        $recipe->likes()->delete();
        $recipe->bookmarks()->delete();
        $recipe->reviews()->delete();

        $recipe->delete();

        return response()->json(['success' => true]);
    }


}
