<?php

namespace App\Http\Controllers;

use App\Models\RecipeCategory;

class RecipeCategoryController extends Controller
{
    public function index()
    {
        $cats = RecipeCategory::query()
            ->orderBy('name')
            ->get(['id', 'name', 'slug']);

        return response()->json([
            'success' => true,
            'data' => $cats,
        ]);
    }
}
