<?php

use App\Http\Controllers\{
    RecipeController,
    RecipeTrendingController,
    RecipeLikeController,
    RecipeBookmarkController,
    RecipeCommentController,
    RecipeReviewController,
    RecipeCategoryController,
    RecipeTagController,
    AdminRecipeController
};

use App\Http\Controllers\NotificationController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\VendorController;
use App\Http\Controllers\ProductController;
use App\Http\Controllers\CategoryController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\CartController;
use App\Http\Controllers\OrderController;
use App\Http\Controllers\VendorOrderController;
use App\Http\Controllers\ReviewController;
use App\Http\Controllers\WishlistController;
use App\Http\Controllers\VendorDashboardController;
use App\Http\Controllers\UploadController;
use App\Http\Controllers\VendorWishlistController;


Route::pattern('recipe', '[0-9]+');
Route::pattern('comment', '[0-9]+');

// Default user route
Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

Route::get('/recipe-categories', [RecipeCategoryController::class, 'index']);
Route::get('/recipe-tags', [RecipeTagController::class, 'index']);

// Public recipes
Route::get('/recipes', [RecipeController::class, 'index']);
Route::get('/recipes/trending/week', [RecipeTrendingController::class, 'week']);
Route::get('/recipes/{recipe}', [RecipeController::class, 'show']);
Route::get('/recipes/{recipe}/comments', [RecipeCommentController::class, 'index']);
Route::get('/recipes/{recipe}/reviews', [RecipeReviewController::class, 'index']);


// Auth
Route::post('/login', [AuthController::class, 'login']);
Route::post('/register', [AuthController::class, 'register']);

// Public products list (if you want it public)
Route::get('/products', [ProductController::class, 'index']);
Route::get('/products/{product}', [ProductController::class, 'show']);

// Public: list reviews
Route::get('/products/{product}/reviews', [ReviewController::class, 'index']);

// Public categories list 
Route::get('/categories', [CategoryController::class, 'index']);


Route::middleware('auth:sanctum')->group(function () {

    // Optional: auth /me route using AuthController@me
    Route::get('/me', [AuthController::class, 'me']);
    Route::put('/me', [AuthController::class, 'updateProfile']);
    Route::post('/me/change-password', [AuthController::class, 'changePassword']);

    // VENDOR REQUEST FLOW (logged-in users)
    Route::get('/vendors/me', [VendorController::class, 'me']);
    Route::get('/vendor/dashboard', [VendorDashboardController::class, 'index']);
    Route::get('/vendors', [VendorController::class, 'index']);   // list approved vendors
    Route::post('/vendors', [VendorController::class, 'store']);  // request to become vendor
    Route::get('/vendors/{vendor}', [VendorController::class, 'show']);
    Route::get('/vendors/{vendor}/products', [VendorController::class, 'products']);
    Route::put('/vendors/{id}', [VendorController::class, 'update']);
    Route::delete('/vendors/{id}', [VendorController::class, 'destroy']);

    Route::post('/uploads', [UploadController::class, 'store']);

    // PRODUCT CRUD (vendor only logically, but auth:sanctum is enough here for now)
    Route::post('/products', [ProductController::class, 'store']);
    Route::get('/products/mine', [ProductController::class, 'myProducts']);
    Route::post('/products/{product}/reviews', [ReviewController::class, 'store']);
    Route::put('/products/{product}', [ProductController::class, 'update']);
    Route::delete('/products/{product}', [ProductController::class, 'destroy']);
    Route::get('/products/{product}/can-review', [ReviewController::class, 'canReview']);


    // CATEGORY CRUD (probably admin, but you already have AdminMiddleware)
    Route::post('/categories', [CategoryController::class, 'store']);
    Route::get('/categories/{id}', [CategoryController::class, 'show']);
    Route::put('/categories/{category}', [CategoryController::class, 'update']);
    Route::delete('/categories/{id}', [CategoryController::class, 'destroy']);

    // Cart
    Route::get('/cart', [CartController::class, 'index']);
    Route::post('/cart', [CartController::class, 'store']);
    Route::put('/cart/{cartItem}', [CartController::class, 'update']);
    Route::delete('/cart/{cartItem}', [CartController::class, 'destroy']);
    Route::delete('/cart/clear', [CartController::class, 'clear']);

    //Order
    Route::get('/orders', [OrderController::class, 'index']);
    Route::get('/orders/{order}', [OrderController::class, 'show']);
    Route::post('/orders/checkout', [OrderController::class, 'checkoutFromCart']);

    //Vendor Order
    Route::get('/vendor/orders', [VendorOrderController::class, 'index']);
    Route::get('/vendor/orders/{order}', [VendorOrderController::class, 'show']);

    //Whishlist
    Route::get('/wishlist', [WishlistController::class, 'index']);
    Route::post('/wishlist', [WishlistController::class, 'store']);
    Route::delete('/wishlist/{product}', [WishlistController::class, 'destroy']);
    Route::get('/wishlist/vendors', [VendorWishlistController::class, 'index']);
    Route::post('/wishlist/vendors', [WishlistController::class, 'storeVendor']);
    Route::delete('/wishlist/vendors/{vendor}', [WishlistController::class, 'destroyVendor']);

    // Notifications
    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::get('/notifications/unread-count', [NotificationController::class, 'unreadCount']);
    Route::post('/notifications/read-all', [NotificationController::class, 'markAllRead']);
    Route::post('/notifications/{id}/read', [NotificationController::class, 'markRead']);
    Route::delete('/notifications/{id}', [NotificationController::class, 'destroy']);

    // Recipes
    Route::post('/recipes', [RecipeController::class, 'store']);
    Route::get('/recipes/mine', [RecipeController::class, 'mine']);
    Route::post('/recipes/{recipe}/like', [RecipeLikeController::class, 'store']);
    Route::delete('/recipes/{recipe}/like', [RecipeLikeController::class, 'destroy']);
    Route::post('/recipes/{recipe}/bookmark', [RecipeBookmarkController::class, 'store']);
    Route::delete('/recipes/{recipe}/bookmark', [RecipeBookmarkController::class, 'destroy']);
    Route::post('/recipes/{recipe}/comments', [RecipeCommentController::class, 'store']);
    Route::delete('/recipes/comments/{comment}', [RecipeCommentController::class, 'destroy']);
    Route::post('/recipes/{recipe}/review', [RecipeReviewController::class, 'upsert']);
    Route::delete('/recipes/{recipe}/review', [RecipeReviewController::class, 'destroyMy']);
    Route::get('/recipes/bookmarks', [RecipeController::class, 'bookmarks']);
    Route::delete('/recipes/{recipe}', [RecipeController::class, 'destroy'])->whereNumber('recipe');


    // ================= ADMIN VENDOR APPROVAL =================
    Route::middleware(\App\Http\Middleware\AdminMiddleware::class)->prefix('admin')->group(function () {
        Route::get('/vendors/pending', [VendorController::class, 'pending']);
        Route::patch('/vendors/{id}/approve', [VendorController::class, 'approve']);
        Route::patch('/vendors/{id}/reject', [VendorController::class, 'reject']);
        Route::get('/recipes/pending', [AdminRecipeController::class, 'pending']);
        Route::get('/recipes/{recipe}', [RecipeController::class, 'show'])->whereNumber('recipe');
        Route::patch('/recipes/{recipe}/approve', [AdminRecipeController::class, 'approve']);
        Route::patch('/recipes/{recipe}/reject', [AdminRecipeController::class, 'reject']);
    });
});
