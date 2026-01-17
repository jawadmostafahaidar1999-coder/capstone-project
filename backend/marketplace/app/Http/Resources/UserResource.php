<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $vendor = $this->vendor; // relation: User hasOne Vendor

        return [
            'id'        => $this->id,
            'name'      => $this->name,
            'email'     => $this->email,
            'role'      => $this->role,
            // true only if vendor profile exists AND approved
            'is_vendor' => $vendor && $vendor->status === 'approved',
            'vendor'    => $this->whenLoaded('vendor', function () use ($vendor) {
                return [
                    'id'          => $vendor->id,
                    'store_name'  => $vendor->store_name,
                    'status'      => $vendor->status,
                ];
            }),
        ];
    }
}
