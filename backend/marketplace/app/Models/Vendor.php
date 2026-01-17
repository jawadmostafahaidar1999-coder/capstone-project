<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Vendor extends Model
{
    protected $fillable = [
        'user_id',
        'store_name',
        'description',
        'address',
        'phone',
        'image',
        'order_duration_minutes',
        'status',
    ];
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function products()
    {
        return $this->hasMany(Product::class);
    }
    protected $casts = [
        'order_duration_minutes' => 'integer',
    ];
}

