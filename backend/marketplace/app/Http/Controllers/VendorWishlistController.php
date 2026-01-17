<?php

namespace App\Http\Controllers;

use App\Http\Resources\VendorResource;
use App\Models\Vendor;
use App\Models\VendorWishlistItem;
use Illuminate\Http\Request;

class VendorWishlistController extends Controller
{
    // GET /wishlist/vendors
    public function index(Request $request)
    {
        $user = $request->user();

        $items = VendorWishlistItem::where('user_id', $user->id)
            ->with('vendor')
            ->get()
            ->pluck('vendor')
            ->filter();

        return response()->json([
            'success' => true,
            'message' => 'Favorite vendors',
            'data' => [
                'items' => VendorResource::collection($items),
            ],
        ]);
    }

    // POST /wishlist/vendors { vendor_id }
    public function store(Request $request)
    {
        $user = $request->user();

        $validated = $request->validate([
            'vendor_id' => ['required', 'exists:vendors,id'],
        ]);

        $vendor = Vendor::findOrFail($validated['vendor_id']);

        VendorWishlistItem::firstOrCreate([
            'user_id'   => $user->id,
            'vendor_id' => $vendor->id,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Added vendor to favorites',
            'data'    => new VendorResource($vendor),
        ], 201);
    }

    // DELETE /wishlist/vendors/{vendor}
    public function destroy(Request $request, Vendor $vendor)
    {
        $user = $request->user();

        VendorWishlistItem::where('user_id', $user->id)
            ->where('vendor_id', $vendor->id)
            ->delete();

        return response()->json([
            'success' => true,
            'message' => 'Removed vendor from favorites',
        ]);
    }
}
