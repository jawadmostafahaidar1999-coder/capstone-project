<?php

namespace App\Notifications;

use App\Models\Recipe;
use App\Models\RecipeReview;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;

class RecipeReviewedNotification extends Notification
{
    use Queueable;

    public function __construct(
        public RecipeReview $review,
        public Recipe $recipe,
        public User $reviewer,
    ) {}

    public function via($notifiable): array
    {
        return ['database'];
    }

    public function toDatabase($notifiable): array
    {
        $rating = (int) $this->review->rating;

        return [
            'title' => 'New recipe review',
            'body'  => "{$this->reviewer->name} rated your recipe \"{$this->recipe->title}\" {$rating}★",
            'payload' => [
                'type' => 'recipe_review',
                'recipe_id' => $this->recipe->id,
                'review_id' => $this->review->id,
                'rating' => $rating,
            ],
            'deeplink' => [
                'screen' => 'recipe_details',
                'id' => $this->recipe->id,
            ],
        ];
    }
}
