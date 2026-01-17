<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CartItemResource extends JsonResource
{
    /**
     * @property-read \App\Models\CartItem $resource
     */
    public function toArray($request): array
    {
        return [
            'id'         => $this->id,
            'product_id' => $this->product_id,
            'quantity'   => $this->quantity,
            'subtotal'   => $this->subtotal,
            'product'    => new ProductResource($this->whenLoaded('product')),
        ];
    }
}
