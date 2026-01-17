<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreRecipeRequest extends FormRequest
{
    public function authorize(): bool
    {
        return auth()->check();
    }

    public function rules(): array
    {
        return [
            'title' => ['required','string','max:120'],
            'description' => ['nullable','string','max:3000'],

            'category_id' => ['nullable','integer','exists:recipe_categories,id'],
            'tag_ids' => ['nullable','array'],
            'tag_ids.*' => ['integer','exists:recipe_tags,id'],

            'servings' => ['nullable','integer','min:1','max:100'],
            'prep_minutes' => ['nullable','integer','min:0','max:1440'],
            'cook_minutes' => ['nullable','integer','min:0','max:1440'],

            'visibility' => ['nullable', Rule::in(['public','private'])],
            'cover_image' => ['nullable','string','max:255'],

            'ingredients' => ['required','array','min:1'],
            'ingredients.*.name' => ['required','string','max:120'],
            'ingredients.*.quantity' => ['nullable','string','max:40'],
            'ingredients.*.unit' => ['nullable','string','max:40'],
            'ingredients.*.note' => ['nullable','string','max:120'],

            'steps' => ['required','array','min:1'],
            'steps.*.text' => ['required','string','max:2000'],
            'steps.*.timer_minutes' => ['nullable','integer','min:0','max:1440'],
        ];
    }
}
