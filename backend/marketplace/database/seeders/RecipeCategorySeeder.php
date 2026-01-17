<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Str;
use App\Models\RecipeCategory;

class RecipeCategorySeeder extends Seeder
{
    public function run(): void
    {
        $categories = [
            'Starters & Appetizers',
            'Salads',
            'Soups',
            'Sandwiches & Wraps',
            'Desserts',
            'Breakfast',
            'Meals',
            'Drinks',
        ];

        foreach ($categories as $name) {
            $slug = Str::slug($name);

            RecipeCategory::updateOrCreate(
                ['slug' => $slug],
                ['name' => $name]
            );
        }
    }
}
