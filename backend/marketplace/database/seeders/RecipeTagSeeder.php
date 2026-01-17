<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Str;
use App\Models\RecipeTag;

class RecipeTagSeeder extends Seeder
{
    public function run(): void
    {
        $tags = [
            // Cuisines
            'Lebanese','Italian','Mexican','American','French','Greek','Turkish','Syrian',
            'Japanese','Chinese','Korean','Thai','Indian','Mediterranean',

            // Meal types
            'Breakfast','Brunch','Lunch','Dinner','Snack','Late Night',

            // Diet & Lifestyle
            'Healthy','Vegan','Vegetarian','Keto','Gluten-Free','Dairy-Free','Low Carb','High Protein',

            // Cooking style
            'Grilled','Baked','Fried','Roasted','Air Fryer','Slow Cooker','Instant Pot',
            'One Pot','No Bake','No Cook','Quick & Easy',

            // Flavor & spice
            'Spicy','Mild','Sweet','Savory',

            // Restaurant-style categories / popular items
            'Coffee','Tea','Smoothie','Juice','Bakery','Dessert','Pasta','Pizza','Burger',
            'Sandwich','Salad','Soup','BBQ','Seafood','Chicken','Beef',

            // Local / popular
            'Shawarma','Manakish','Kibbeh','Hummus','Tabbouleh','Falafel',
        ];

        // Remove duplicates (just in case)
        $tags = array_values(array_unique($tags));

        foreach ($tags as $name) {
            $slug = Str::slug($name);

            RecipeTag::updateOrCreate(
                ['slug' => $slug],
                ['name' => $name]
            );
        }
    }
}
