<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class VendorResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
         return [
            'id'                     => $this->id,
            'store_name'             => $this->store_name,
            'description'            => $this->description,
            'address'                => $this->address,   // 👈 this is your "location"
            'phone'                  => $this->phone,
            'image'                  => $this->image,     // new vendor image column
            'order_duration_minutes' => $this->order_duration_minutes,
            'status'                 => $this->status,
            'created_at'             => $this->created_at?->toIso8601String(),
            'updated_at'             => $this->updated_at?->toIso8601String(),
        ];
    }
}
