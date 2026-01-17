<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreRecipeCommentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return auth()->check();
    }

    public function rules(): array
    {
        return [
            'body' => ['required','string','max:1500'],
            'parent_id' => ['nullable','integer','exists:recipe_comments,id'],
        ];
    }
}
