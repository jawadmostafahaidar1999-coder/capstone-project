<?php

namespace App\Http\Controllers;

use App\Http\Resources\OrderItemResource;
use App\Models\Order;
use App\Models\OrderItem;
use Illuminate\Http\Request;

class VendorOrderController extends Controller
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

        // Find orders that have at least one item for this vendor
        $orderIds = OrderItem::whereHas('product', function ($q) use ($vendor) {
            $q->where('vendor_id', $vendor->id);
        })->pluck('order_id')->unique();

        if ($orderIds->isEmpty()) {
            return response()->json([
                'success' => true,
                'message' => 'Vendor orders',
                'data' => [
                    'items' => [],
                ],
            ]);
        }

        $orders = Order::with(['user', 'items.product.vendor', 'items.product.category'])
            ->whereIn('id', $orderIds)
            ->orderByDesc('created_at')
            ->get();

        $result = $orders->map(function (Order $order) use ($vendor) {
            // Only include items belonging to this vendor
            $vendorItems = $order->items->filter(function ($item) use ($vendor) {
                return $item->product && $item->product->vendor_id === $vendor->id;
            });

            return [
                'id'          => $order->id,
                'total_price' => $order->total_price,
                'status'      => $order->status,
                'created_at'  => $order->created_at?->toDateTimeString(),
                'customer'    => [
                    'id'    => $order->user->id,
                    'name'  => $order->user->name,
                    'email' => $order->user->email,
                ],
                'items'       => OrderItemResource::collection($vendorItems)->resolve(),
            ];
        });

        return response()->json([
            'success' => true,
            'message' => 'Vendor orders',
            'data' => [
                'items' => $result,
            ],
        ]);
    }

    public function show(Request $request, Order $order)
    {
        $user = $request->user();
        $vendor = $user->vendor;

        if (!$vendor || $vendor->status !== 'approved') {
            return response()->json([
                'success' => false,
                'message' => 'You are not an approved vendor',
            ], 403);
        }

        $order->load(['user', 'items.product.vendor', 'items.product.category']);

        // Check this order actually has items for this vendor
        $vendorItems = $order->items->filter(function ($item) use ($vendor) {
            return $item->product && $item->product->vendor_id === $vendor->id;
        });

        if ($vendorItems->isEmpty()) {
            return response()->json([
                'success' => false,
                'message' => 'Order does not contain your products',
            ], 404);
        }

        $payload = [
            'id'          => $order->id,
            'total_price' => $order->total_price,
            'status'      => $order->status,
            'created_at'  => $order->created_at?->toDateTimeString(),
            'customer'    => [
                'id'    => $order->user->id,
                'name'  => $order->user->name,
                'email' => $order->user->email,
            ],
            'items'       => OrderItemResource::collection($vendorItems)->resolve(),
        ];

        return response()->json([
            'success' => true,
            'message' => 'Vendor order details',
            'data'    => $payload,
        ]);
    }
}
