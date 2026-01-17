<?php

namespace App\Http\Controllers;

use App\Http\Resources\ReviewResource;
use App\Models\Order;
use App\Models\Product;
use App\Models\Review;
use Illuminate\Http\Request;
use App\Notifications\ProductReviewedNotification;


class ReviewController extends Controller
{
    // GET /products/{product}/reviews (public)
    public function index(Product $product)
    {
        $reviews = $product->reviews()
            ->with('user')
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Product reviews',
            'data' => [
                'items' => ReviewResource::collection($reviews),
            ],
        ]);
    }

    /**
     * Helper:
     * user can review if they have at least 1 "paid" or "delivered" order
     * containing any product from this vendor.
     *
     * Your schema:
     * orders -> items -> product -> vendor_id
     */
    private function userHasOrderFromVendor(int $userId, int $vendorId): bool
    {
        return Order::query()
            ->where('user_id', $userId)
            ->whereIn('status', ['paid', 'delivered']) // based on your enum
            ->whereHas('items.product', function ($q) use ($vendorId) {
                $q->where('vendor_id', $vendorId);
            })
            ->exists();
    }

    // GET /products/{product}/can-review (auth)
    public function canReview(Product $product)
    {
        $user = request()->user();
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthenticated',
            ], 401);
        }

        $vendorId = (int) $product->vendor_id;
        $can = $this->userHasOrderFromVendor($user->id, $vendorId);

        return response()->json([
            'success' => true,
            'message' => 'Can review',
            'data' => [
                'can_review' => $can,
                'reason' => $can ? null : 'You can only review after at least 1 paid/delivered order from this store.',
            ],
        ]);
    }

    // POST /products/{product}/reviews (auth)
    public function store(Request $request, Product $product)
    {
        $user = $request->user();
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthenticated',
            ], 401);
        }

        // ✅ Enforce "ordered from this store" rule
        $vendorId = (int) $product->vendor_id;
        $hasOrderedFromStore = $this->userHasOrderFromVendor($user->id, $vendorId);

        if (!$hasOrderedFromStore) {
            return response()->json([
                'success' => false,
                'message' => 'You can only review after at least 1 paid/delivered order from this store.',
            ], 403);
        }

        $validated = $request->validate([
            'rating' => ['required', 'integer', 'min:1', 'max:5'],
            'comment' => ['nullable', 'string'],
        ]);

        $review = Review::updateOrCreate(
            [
                'user_id' => $user->id,
                'product_id' => $product->id,
            ],
            [
                'rating' => $validated['rating'],
                'comment' => $validated['comment'] ?? null,
            ]
        );

        // notify only on FIRST creation (avoid spamming on edits)
        if ($review->wasRecentlyCreated) {
            $product->loadMissing('vendor.user');

            $vendorUser = optional(optional($product->vendor)->user);

            if ($vendorUser && $vendorUser->id !== $user->id) {
                $vendorUser->notify(
                    new ProductReviewedNotification(
                        review: $review,
                        product: $product,
                        reviewer: $user
                    )
                );
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'Review saved',
            'data' => new ReviewResource($review),
        ], 201);

    }
}