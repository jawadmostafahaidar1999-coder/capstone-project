<?php

namespace App\Notifications;

use App\Models\Product;
use App\Models\Review;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;

class ProductReviewedNotification extends Notification
{
    use Queueable;

    public function __construct(
        public Review $review,
        public Product $product,
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
            'title' => 'New product review',
            'body'  => "{$this->reviewer->name} rated \"{$this->product->name}\" {$rating}★",
            'payload' => [
                'type' => 'product_review',
                'product_id' => $this->product->id,
                'vendor_id' => $this->product->vendor_id,
                'review_id' => $this->review->id,
                'rating' => $rating,
            ],
            // Flutter can use this to navigate later
            'deeplink' => [
                'screen' => 'product_details',
                'id' => $this->product->id,
            ],
        ];
    }
}
