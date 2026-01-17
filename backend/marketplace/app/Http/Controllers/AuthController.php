<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use App\Models\User;

class AuthController extends Controller
{
    /**
     * Return the authenticated user (with vendor info if exists).
     */
    public function me(Request $request)
    {
        $user = $request->user()->load('vendor');

        return $this->success(
            $this->transformUser($user),
            'Authenticated user'
        );
    }

    /**
     * Login user and return token + user.
     */
    public function login(Request $request)
    {
        $data = $request->validate([
            'email' => 'required|email',
            'password' => 'required',
        ]);

        $user = User::where('email', $data['email'])->first();

        if (!$user || !Hash::check($data['password'], $user->password)) {
            return $this->error('Invalid login information', 401);
        }

        $token = $user->createToken('mobile')->plainTextToken;

        return $this->success([
            'token' => $token,
            'user' => $this->transformUser($user->load('vendor')),
        ], 'Login successful');
    }

    /**
     * Register as a NORMAL user (never vendor directly).
     */
    public function register(Request $request)
    {
        $fields = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|unique:users,email',
            'password' => 'required|string|min:6',
        ]);

        $user = User::create([
            'name' => $fields['name'],
            'email' => $fields['email'],
            'password' => bcrypt($fields['password']),
            // 🔴 Always a normal user at registration
            'role' => 'user',
        ]);

        $token = $user->createToken('mobile')->plainTextToken;

        return $this->success([
            'token' => $token,
            'user' => $this->transformUser($user),
        ], 'Register successful', 201);
    }

    public function updateProfile(Request $request)
    {
        $user = $request->user();

        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:255'],

        ]);

        if (array_key_exists('name', $data)) {
            $user->name = $data['name'];
        }

        // If image uploaded as a file (multipart/form-data)
        if ($request->hasFile('image')) {
            $request->validate([
                'image' => 'image|max:4096', // 4MB
            ]);

            $path = $request->file('image')->store('avatars', 'public');
            $user->image = '/storage/' . $path; // store relative path (best for emulator/web)
        }

        // (optional) keep URL support if you still want it
        // else if ($request->filled('image')) { $user->image = $request->input('image'); }

        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Profile updated',
            'data' => $user, // or your UserResource
        ]);
    }

    public function changePassword(Request $request)
    {
        $user = $request->user();

        $data = $request->validate([
            'current_password' => ['required', 'current_password'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            // expects 'password_confirmation'
        ]);

        $user->password = Hash::make($data['password']);
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Password changed successfully',
        ]);
    }
    /**
     * Helper to shape user data for the API.
     */
    protected function transformUser(User $user): array
    {
        $vendor = $user->vendor; // hasOne relation

        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role' => $user->role,
            'is_vendor' => $vendor && $vendor->status === 'approved',
            'image' => $user->image,
            'vendor' => $vendor ? [

                'id' => $vendor->id,
                'store_name' => $vendor->store_name,
                'description' => $vendor->description,
                'address' => $vendor->address,   // 👈 this is your location
                'phone' => $vendor->phone,
                'image' => $vendor->image,
                'order_duration_minutes' => $vendor->order_duration_minutes,
                'status' => $vendor->status,

            ] : null,
        ];
    }
}
