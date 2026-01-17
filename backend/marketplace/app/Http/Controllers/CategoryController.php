<?php

namespace App\Http\Controllers;

use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use App\Http\Resources\CategoryResource;

class CategoryController extends Controller
{
    // GET /categories?per_page=10&page=1
    public function index(Request $request)
    {
        $perPage = (int) $request->query('per_page', 10);

        $categories = Category::orderBy('name')->paginate($perPage);

        return $this->paginated(
            $categories,
            CategoryResource::collection($categories),
            'Categories list'
        );
    }

    // POST /categories
    public function store(Request $request)
    {
        $request->validate([
            'name'  => 'required|string|max:255',
            'image' => 'nullable|image|mimes:jpg,jpeg,png,webp|max:2048',
        ]);

        $imagePath = null;

        if ($request->hasFile('image')) {
            $imagePath = $request->file('image')->store('categories', 'public');
        }

        $category = Category::create([
            'name'  => $request->name,
            'image' => $imagePath,
        ]);

        return $this->success(
            new CategoryResource($category),
            'Category created',
            201
        );
    }

    // GET /categories/{category}
    public function show(Category $category)
    {
        return $this->success(
            new CategoryResource($category),
            'Category details'
        );
    }

    // PUT /categories/{category}
    public function update(Request $request, Category $category)
    {
        $request->validate([
            'name'  => 'required|string|max:255',
            'image' => 'nullable|image|mimes:jpg,jpeg,png,webp|max:2048',
        ]);

        if ($request->hasFile('image')) {
            if ($category->image && Storage::disk('public')->exists($category->image)) {
                Storage::disk('public')->delete($category->image);
            }

            $category->image = $request->file('image')->store('categories', 'public');
        }

        $category->name = $request->name;
        $category->save();

        return $this->success(
            new CategoryResource($category),
            'Category updated'
        );
    }

    // DELETE /categories/{category}
    public function destroy(Category $category)
    {
        if ($category->image && Storage::disk('public')->exists($category->image)) {
            Storage::disk('public')->delete($category->image);
        }

        $category->delete();

        return $this->success(null, 'Category deleted');
    }
}
