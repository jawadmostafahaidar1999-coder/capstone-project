<?php

namespace App\Http\Controllers;

use App\Models\RecipeTag;
use Illuminate\Http\Request;

class RecipeTagController extends Controller
{
    public function index(Request $request)
    {
        $search = trim((string) $request->query('search', ''));

        $tags = RecipeTag::query()
            ->when($search !== '', fn($q) => $q->where('name', 'like', "%{$search}%"))
            ->orderBy('name')
            ->get(['id','name','slug']);

        return response()->json(['data' => $tags]);
    }
}
