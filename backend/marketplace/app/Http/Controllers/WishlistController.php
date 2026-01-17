<?php

namespace App\Http\Controllers;

use App\Http\Resources\ProductResource;
use App\Http\Resources\VendorResource;
use App\Models\Product;
use App\Models\Vendor;
use App\Models\WishlistItem;
use App\Models\VendorWishlistItem;
use Illuminate\Http\Request;

class WishlistController extends Controller
{
    // GET /wishlist
    public function index(Request $request)
    {
        $user = $request->user();

        $products = WishlistItem::where('user_id', $user->id)
            ->with('product.category', 'product.vendor')
            ->get()
            ->pluck('product')
            ->filter()
            ->values();

        $vendors = VendorWishlistItem::where('user_id', $user->id)
            ->with('vendor')
            ->get()
            ->pluck('vendor')
            ->filter()
            ->values();

        return response()->json([
            'success' => true,
            'message' => 'Wishlist',
            'data' => [
                // new
                'vendors' => VendorResource::collection($vendors),
                'products' => ProductResource::collection($products),

                // backward compatible for older flutter code
                'items' => ProductResource::collection($products),
            ],
        ]);
    }

    // POST /wishlist  { product_id }
    public function store(Request $request)
    {
        $user = $request->user();

        $validated = $request->validate([
            'product_id' => ['required', 'exists:products,id'],
        ]);

        $product = Product::findOrFail($validated['product_id']);

        WishlistItem::firstOrCreate([
            'user_id'    => $user->id,
            'product_id' => $product->id,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Added product to wishlist',
            'data'    => new ProductResource($product->load('category', 'vendor')),
        ], 201);
    }

    // DELETE /wishlist/{product}
    public function destroy(Request $request, Product $product)
    {
        $user = $request->user();

        WishlistItem::where('user_id', $user->id)
            ->where('product_id', $product->id)
            ->delete();

        return response()->json([
            'success' => true,
            'message' => 'Removed product from wishlist',
        ]);
    }

    // POST /wishlist/vendors  { vendor_id }
    public function storeVendor(Request $request)
    {
        $user = $request->user();

        $validated = $request->validate([
            'vendor_id' => ['required', 'exists:vendors,id'],
        ]);

        $vendor = Vendor::findOrFail($validated['vendor_id']);

        VendorWishlistItem::firstOrCreate([
            'user_id' => $user->id,
            'vendor_id' => $vendor->id,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Added vendor to wishlist',
            'data' => new VendorResource($vendor),
        ], 201);
    }

    // DELETE /wishlist/vendors/{vendor}
    public function destroyVendor(Request $request, Vendor $vendor)
    {
        $user = $request->user();

        VendorWishlistItem::where('user_id', $user->id)
            ->where('vendor_id', $vendor->id)
            ->delete();

        return response()->json([
            'success' => true,
            'message' => 'Removed vendor from wishlist',
        ]);
    }
}
