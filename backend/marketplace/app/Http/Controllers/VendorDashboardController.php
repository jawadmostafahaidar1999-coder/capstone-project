<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Review;
use Illuminate\Http\Request;

class VendorDashboardController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        $vendor = $user->vendor;

        if (!$vendor || $vendor->status !== 'approved') {
            return response()->json([
                'success' => false,
                'message' => 'You are not an approved vendor',
            ], 403);
        }

        // All product ids for this vendor
        $productIds = $vendor->products()->pluck('id');

        $totalProducts = $productIds->count();

        if ($productIds->isEmpty()) {
            return response()->json([
                'success' => true,
                'message' => 'Vendor dashboard',
                'data' => [
                    'store_name'      => $vendor->store_name,
                    'total_products'  => 0,
                    'total_orders'    => 0,
                    'total_items_sold'=> 0,
                    'total_revenue'   => 0,
                    'pending_orders'  => 0,
                    'rating_avg'      => 0,
                    'rating_count'    => 0,
                ],
            ]);
        }

        // Order items for this vendor's products
        $orderItems = OrderItem::whereIn('product_id', $productIds)->get();

        $totalItemsSold = (int) $orderItems->sum('quantity');

        $totalRevenue = $orderItems->reduce(
            fn ($carry, $item) => $carry + ($item->price * $item->quantity),
            0
        );

        $orderIds = $orderItems->pluck('order_id')->unique();
        $totalOrders = $orderIds->count();

        $pendingOrders = $orderIds->isEmpty()
            ? 0
            : Order::whereIn('id', $orderIds)
                ->where('status', 'pending')
                ->count();

        // Reviews for this vendor's products
        $ratingQuery = Review::whereIn('product_id', $productIds);
        $ratingAvg = (float) $ratingQuery->avg('rating');
        $ratingCount = (int) $ratingQuery->count();

        return response()->json([
            'success' => true,
            'message' => 'Vendor dashboard',
            'data' => [
                'store_name'       => $vendor->store_name,
                'total_products'   => $totalProducts,
                'total_orders'     => $totalOrders,
                'total_items_sold' => $totalItemsSold,
                'total_revenue'    => $totalRevenue,
                'pending_orders'   => $pendingOrders,
                'rating_avg'       => round($ratingAvg, 1),
                'rating_count'     => $ratingCount,
            ],
        ]);
    }
}
