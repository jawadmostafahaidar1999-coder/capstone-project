<?php

namespace App\Http\Controllers;

use App\Http\Resources\CartItemResource;
use App\Models\CartItem;
use App\Models\Product;
use Illuminate\Http\Request;

class CartController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();

        $items = $user->cartItems()
            ->with('product.category', 'product.vendor')
            ->get();

        $totalQuantity = $items->sum('quantity');
        $totalPrice = $items->sum(fn ($item) => $item->subtotal);

        return response()->json([
            'success' => true,
            'message' => 'Cart items',
            'data' => [
                'items'          => CartItemResource::collection($items),
                'total_quantity' => $totalQuantity,
                'total_price'    => $totalPrice,
            ],
        ]);
    }

    public function store(Request $request)
    {
        $user = $request->user();

        $validated = $request->validate([
            'product_id' => ['required', 'exists:products,id'],
            'quantity'   => ['nullable', 'integer', 'min:1'],
        ]);

        $product  = Product::findOrFail($validated['product_id']);
        $quantity = $validated['quantity'] ?? 1;

        // if already exists, increment quantity
        $item = CartItem::where('user_id', $user->id)
            ->where('product_id', $product->id)
            ->first();

        if ($item) {
            $item->quantity += $quantity;
            $item->save();
        } else {
            $item = CartItem::create([
                'user_id'    => $user->id,
                'product_id' => $product->id,
                'quantity'   => $quantity,
            ]);
        }

        $item->load('product.category', 'product.vendor');

        return response()->json([
            'success' => true,
            'message' => 'Item added to cart',
            'data'    => new CartItemResource($item),
        ], 201);
    }

    public function update(Request $request, CartItem $cartItem)
    {
        $user = $request->user();

        if ($cartItem->user_id !== $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'Not allowed to modify this cart item',
            ], 403);
        }

        $validated = $request->validate([
            'quantity' => ['required', 'integer', 'min:1'],
        ]);

        $cartItem->quantity = $validated['quantity'];
        $cartItem->save();

        $cartItem->load('product.category', 'product.vendor');

        return response()->json([
            'success' => true,
            'message' => 'Cart item updated',
            'data'    => new CartItemResource($cartItem),
        ]);
    }

    public function destroy(Request $request, CartItem $cartItem)
    {
        $user = $request->user();

        if ($cartItem->user_id !== $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'Not allowed to delete this cart item',
            ], 403);
        }

        $cartItem->delete();

        return response()->json([
            'success' => true,
            'message' => 'Cart item removed',
        ]);
    }

    public function clear(Request $request)
    {
        $user = $request->user();

        $user->cartItems()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Cart cleared',
        ]);
    }
}
