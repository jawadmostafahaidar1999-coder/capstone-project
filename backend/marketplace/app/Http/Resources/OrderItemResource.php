<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use App\Http\Resources\ProductResource;


class OrderItemResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
         return [
            'id'          => $this->id,
            'product_id'  => $this->product_id,
            'quantity'    => $this->quantity,
            'price'       => $this->price,
            'total'       => (float) $this->quantity * (float) $this->price,
            'product'     => new ProductResource($this->whenLoaded('product')),
        ];
    }
}
