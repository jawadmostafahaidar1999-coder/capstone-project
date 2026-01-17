<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            "id" => $this->id,
            "name" => $this->name,
            "description" => $this->description,
            "price" => (float) $this->price,
            "stock" => $this->stock,
            "image" => $this->image,
            "status" => $this->status,
            'is_offer' => (bool) ($this->is_offer ?? false),
            'offer_ends_at' => $this->offer_ends_at?->toIso8601String(),
            'category' => $this->whenLoaded('category', function () {
                return [
                    'id' => $this->category->id,
                    'name' => $this->category->name,
                ];
            }),
            'vendor' => $this->whenLoaded('vendor', function () {
                return [
                    'id' => $this->vendor->id,
                    'store_name' => $this->vendor->store_name,
                    'description' => $this->vendor->description,
                    'address' => $this->vendor->address,
                    'phone' => $this->vendor->phone,
                    'image' => $this->vendor->image,
                    'status' => $this->vendor->status,
                ];
            }),
            "created_at" => $this->created_at?->toDateTimeString(),
            'average_rating' => round($this->reviews()->avg('rating') ?? 0, 1),
            'reviews_count' => $this->reviews()->count(),
        ];
    }
}
