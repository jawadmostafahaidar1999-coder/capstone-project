<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class NotificationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $data = is_array($this->data) ? $this->data : [];

        return [
            'id' => $this->id,
            'type' => class_basename($this->type),
            'title' => $data['title'] ?? null,
            'body' => $data['body'] ?? null,
            'payload' => $data['payload'] ?? null,
            'deeplink' => $data['deeplink'] ?? null,
            'read_at' => optional($this->read_at)->toDateTimeString(),
            'created_at' => optional($this->created_at)->toDateTimeString(),
        ];
    }
}
