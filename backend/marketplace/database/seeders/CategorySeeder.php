<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Category;

class CategorySeeder extends Seeder
{
    public function run(): void
    {
        $names = [
            'Breakfast',
            'Sandwiches',
            'Salads',
            'Lunch',
            'Meals',
            'Dessert',
            'Drinks',
        ];

        foreach ($names as $name) {
            Category::firstOrCreate(
                ['name' => $name],
                ['image' => null]
            );
        }
    }
}
