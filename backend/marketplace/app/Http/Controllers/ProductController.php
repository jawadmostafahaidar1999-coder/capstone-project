<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Models\Vendor;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Http\Resources\ProductResource;

class ProductController extends Controller
{
    // PUBLIC (if you want): GET /products?search=&category_id=&vendor_id=&sort=&per_page=&page=
    public function index(Request $request)
    {
        $perPage = (int) $request->query('per_page', 10);
        $search = $request->query('search');
        $categoryId = $request->query('category_id');
        $vendorId = $request->query('vendor_id');
        $sort = $request->query('sort', 'newest'); // newest | price_asc | price_desc

        $query = Product::with(['vendor', 'category'])
            ->where('status', 'active');

        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('description', 'like', "%{$search}%");
            });
        }

        if ($categoryId) {
            $query->where('category_id', $categoryId);
        }

        if ($vendorId) {
            $query->where('vendor_id', $vendorId);
        }

        switch ($sort) {
            case 'price_asc':
                $query->orderBy('price', 'asc');
                break;
            case 'price_desc':
                $query->orderBy('price', 'desc');
                break;
            default:
                $query->latest(); // created_at desc
        }

        $products = $query
            ->with(['category', 'vendor']) // 👈 important for nested JSON
            ->paginate($perPage);

        return $this->paginated(
            $products,
            ProductResource::collection($products),
            'Products list'
        );
    }

    // Optional: GET /products/{product}
    // public function show(Product $product)
    // {
    //   $product->load(['vendor', 'category']);

    //    return $this->success(
    //        new ProductResource($product),
    //        'Product details'
    //    );
    //}

    public function show($id)
    {
        $product = Product::with(['category', 'vendor'])->find($id);

        if (!$product) {
            return $this->error('Product not found', 404);
        }

        return $this->success(
            new ProductResource($product),
            'Product details'
        );
    }

    // Vendor: POST /products
    public function store(Request $request)
    {
        $user = $request->user();
        $vendor = $user->vendor;

        if (!$vendor || $vendor->status !== 'approved') {
            return response()->json([
                'success' => false,
                'message' => 'You must be an approved vendor to create products.',
            ], 403);
        }

        $data = $request->validate([
            'category_id' => 'required|exists:categories,id',
            'name' => 'required|string|max:255',
            'price' => 'required|numeric|min:0',
            'stock' => 'nullable|integer|min:0',
            'description' => 'nullable|string',
            'image' => 'nullable|string|max:2048',
            'is_offer' => ['sometimes', 'boolean'],
            'offer_duration_days' => ['sometimes', 'nullable', 'integer', 'min:1', 'max:365'],
        ]);

        if ($request->hasFile('image')) {
            $request->validate(['image' => 'image|max:4096']);
            $path = $request->file('image')->store('products', 'public');
            $data['image'] = '/storage/' . $path;
        }

        $isOffer = $data['is_offer'] ?? false;

        $offerEndsAt = null;
        if ($isOffer && !empty($data['offer_duration_days'])) {
            $offerEndsAt = now()->addDays($data['offer_duration_days']);
        }

        $product = $vendor->products()->create([
            'vendor_id' => $vendor->id,
            'category_id' => $data['category_id'],
            'name' => $data['name'],
            'description' => $data['description'] ?? null,
            'price' => $data['price'],
            'stock' => isset($data['stock']) ? $data['stock'] : 0,
            'image' => $data['image'] ?? null,
            'status' => 'active',
            'is_offer' => $isOffer,
            'offer_ends_at' => $offerEndsAt,
        ]);

        return $this->success(
            new ProductResource($product),
            'Product created',
            201
        );
    }

    public function offers()
    {
        $products = Product::where('is_offer', true)
            ->where(function ($q) {
                $q->whereNull('offer_ends_at')
                    ->orWhere('offer_ends_at', '>=', now());
            })
            ->with(['vendor', 'category'])
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Current offers.',
            'data' => $products,
        ]);
    }

    // Vendor: GET /products/mine?per_page=&page=
    public function myProducts(Request $request)
    {
        $user = $request->user();

        $vendor = Vendor::where('user_id', $user->id)->first();

        if (!$vendor) {
            return $this->error('You are not a vendor.', 403);
        }

        $perPage = (int) $request->query('per_page', 10);

        $products = Product::with('category')
            ->where('vendor_id', $vendor->id)
            ->latest()
            ->paginate($perPage);

        return $this->paginated(
            $products,
            ProductResource::collection($products),
            'My products'
        );
    }

    // Vendor: PUT /products/{product}
    public function update(Request $request, Product $product)
    {
        $user = $request->user();

        $vendor = Vendor::where('user_id', $user->id)->first();

        if (!$vendor || $product->vendor_id !== $vendor->id) {
            return $this->error('You are not authorized to update this product.', 403);
        }

        $data = $request->validate([
            'category_id' => 'sometimes|exists:categories,id',
            'name' => 'sometimes|string|max:255',
            'description' => 'nullable|string',
            'price' => 'sometimes|numeric|min:0',
            'stock' => 'sometimes|integer|min:0',
            'status' => 'sometimes|in:active,inactive',
            'image' => 'nullable|string',
        ]);

        if ($request->hasFile('image')) {
            $request->validate(['image' => 'image|max:4096']);
            $path = $request->file('image')->store('products', 'public');
            $data['image'] = '/storage/' . $path;
        }

        $product->update($data);

        return $this->success(
            new ProductResource($product->fresh(['vendor', 'category'])),
            'Product updated'
        );
    }

    // Vendor: DELETE /products/{product}
    public function destroy(Request $request, Product $product)
    {
        $user = $request->user();

        $vendor = Vendor::where('user_id', $user->id)->first();

        if (!$vendor || $product->vendor_id !== $vendor->id) {
            return $this->error('You are not authorized to delete this product.', 403);
        }

        $product->delete();

        return $this->success(null, 'Product deleted');
    }
}
