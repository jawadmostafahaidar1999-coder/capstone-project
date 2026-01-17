<?php

namespace App\Http\Controllers;

use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Models\OrderItem;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class OrderController extends Controller
{
    // GET /orders  (current user's orders)
    public function index(Request $request)
    {
        $user = $request->user();

        $orders = $user->orders()
            ->with(['items.product.category', 'items.product.vendor'])
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Your orders',
            'data' => [
                'items' => OrderResource::collection($orders),
            ],
        ]);
    }

    // GET /orders/{order}
    public function show(Request $request, Order $order)
    {
        $user = $request->user();

        if ($order->user_id !== $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'Not allowed to view this order',
            ], 403);
        }

        $order->load(['items.product.category', 'items.product.vendor']);

        return response()->json([
            'success' => true,
            'message' => 'Order details',
            'data'    => new OrderResource($order),
        ]);
    }

    // POST /orders/checkout -> create order from user's cart & clear cart
    public function checkoutFromCart(Request $request)
    {
        $user = $request->user();

        $cartItems = $user->cartItems()->with('product')->get();

        if ($cartItems->isEmpty()) {
            return response()->json([
                'success' => false,
                'message' => 'Cart is empty',
            ], 422);
        }

        $order = DB::transaction(function () use ($user, $cartItems) {
            $total = 0;

            foreach ($cartItems as $item) {
                $price = $item->product->price;
                $total += $price * $item->quantity;
            }

            // use your existing enum: pending|paid|delivered|cancelled
            $order = Order::create([
                'user_id'     => $user->id,
                'total_price' => $total,
                'status'      => 'pending',
            ]);

            $rows = [];

            foreach ($cartItems as $item) {
                $price = $item->product->price;
                $rows[] = [
                    'order_id'    => $order->id,
                    'product_id'  => $item->product_id,
                    'quantity'    => $item->quantity,
                    'price'       => $price, // goes into order_items.price
                    'created_at'  => now(),
                    'updated_at'  => now(),
                ];
            }

            OrderItem::insert($rows);

            // clear cart
            $user->cartItems()->delete();

            return $order;
        });

        $order->load(['items.product.category', 'items.product.vendor']);

        return response()->json([
            'success' => true,
            'message' => 'Order created from cart',
            'data'    => new OrderResource($order),
        ], 201);
    }
}
