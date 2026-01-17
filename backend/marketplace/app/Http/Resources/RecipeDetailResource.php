<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RecipeDetailResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return array_merge((new RecipeResource($this))->toArray($request), [
            'ingredients' => $this->whenLoaded('ingredients', fn () =>
                $this->ingredients->map(fn ($i) => [
                    'id' => $i->id,
                    'name' => $i->name,
                    'quantity' => $i->quantity,
                    'unit' => $i->unit,
                    'note' => $i->note,
                    'sort_order' => $i->sort_order,
                ])
            ),

            'steps' => $this->whenLoaded('steps', fn () =>
                $this->steps->map(fn ($s) => [
                    'id' => $s->id,
                    'text' => $s->text,
                    'timer_minutes' => $s->timer_minutes,
                    'sort_order' => $s->sort_order,
                ])
            ),
        ]);
    }
}
