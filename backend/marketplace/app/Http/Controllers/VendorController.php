<?php

namespace App\Http\Controllers;

use App\Models\Vendor;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Http\Resources\ProductResource;
use App\Http\Resources\VendorResource;


class VendorController extends Controller
{
    /**
     * List approved vendors (for normal users).
     */
    public function index(Request $request)
    {
        $vendors = Vendor::where('status', 'approved')
            ->with('user')
            ->orderBy('store_name')
            ->get();

        return $this->success(
            VendorResource::collection($vendors),
            'Approved vendors list'
        );
    }

    /**
     * Request to become vendor (creates pending vendor record).
     */
    public function store(Request $request)
    {
        $user = $request->user();

        // 1) Only one active request per user
        $existing = $user->vendor; // hasOne

        if ($existing && in_array($existing->status, ['pending', 'approved'])) {
            return response()->json([
                'success' => false,
                'message' => 'You already have a vendor request in progress.',
            ], 422);
        }

        $data = $request->validate([
            'store_name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'address' => 'nullable|string|max:255',
            'phone' => 'nullable|string|max:20',
            'image' => ['nullable', 'string', 'max:2048'],
        ]);

        $vendor = $user->vendor()->create([
            'user_id' => $user->id,
            'store_name' => $data['store_name'],
            'description' => $data['description'] ?? null,
            'address' => $data['address'] ?? null,
            'phone' => $data['phone'] ?? null,
            'image' => $data['image'] ?? null,
            'status' => 'pending',    // status defaults to 'pending' from migration
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Vendor request submitted and is pending approval.',
            'data' => $vendor,
        ], 201);
    }

    /**
     * Show a vendor:
     * - if approved → visible to everyone (auth middleware still runs)
     * - if not approved → only visible to its owner
     */
    public function show(Request $request, $id)
    {
        $vendor = Vendor::with('user')->find($id);

        if (!$vendor) {
            return $this->error('Vendor not found', 404);
        }

        $user = $request->user();

        if ($vendor->status !== 'approved') {
            // only owner (or admin) can see non-approved profiles
            if (!$user || ($user->id !== $vendor->user_id && $user->role !== 'admin')) {
                return $this->error('Vendor not available', 403);
            }
        }

        return $this->success(
            new VendorResource($vendor),
            'Vendor details'
        );
    }

    /**
     * Owner updates own vendor profile (not status).
     */
    public function update(Request $request, $id)
    {
        $user = $request->user();
        $vendor = Vendor::find($id);

        if ($vendor->user_id !== $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'You are not allowed to update this vendor.',
            ], 403);
        }

        if (!$user || $vendor->user_id !== $user->id) {
            return $this->error('You are not authorized to update this vendor profile.', 403);
        }

        $data = $request->validate([
            'store_name' => 'sometimes|string|max:255',
            'description' => 'nullable|string',
            'address' => 'nullable|string|max:255',
            'phone' => 'nullable|string|max:20',
            'image' => ['sometimes', 'nullable', 'string', 'max:2048'],
            'order_duration_minutes' => ['sometimes', 'nullable', 'integer', 'min:0'],
            // status should NOT be updated by vendor here
        ]);

        $vendor->fill($data);
        $vendor->save();

        return response()->json([
            'success' => true,
            'message' => 'Vendor profile updated.',
            'data' => $vendor,
        ]);
    }

    /**
     * Owner deletes own vendor profile.
     */
    public function destroy(Request $request, $id)
    {
        $user = $request->user();
        $vendor = Vendor::find($id);

        if (!$vendor) {
            return $this->error('Vendor not found', 404);
        }

        if (!$user || $vendor->user_id !== $user->id) {
            return $this->error('You are not authorized to delete this vendor profile.', 403);
        }

        $vendor->delete();

        return $this->success(null, 'Vendor deleted successfully.');
    }

    /**
     * Get currently logged-in user's vendor profile (if any).
     * Handy for "My Vendor Profile" screen in Flutter.
     */
    public function myVendor(Request $request)
    {
        $user = $request->user();

        if (!$user) {
            return $this->error('Unauthorized', 401);
        }

        $vendor = $user->vendor;

        if (!$vendor) {
            return $this->error('You do not have a vendor profile.', 404);
        }

        return $this->success($vendor, 'My vendor profile');
    }

    // ===================== ADMIN METHODS =====================

    /**
     * List all pending vendor requests (admin only).
     */
    public function pending(Request $request)
    {
        $vendors = Vendor::where('status', 'pending')
            ->with('user')
            ->orderBy('created_at', 'asc')
            ->get();

        return $this->success($vendors, 'Pending vendor requests');
    }

    /**
     * Approve a vendor (admin only).
     * - set vendor->status = 'approved'
     * - set user->role = 'vendor' (optional, but nice)
     */
    public function approve($id)
    {
        $vendor = Vendor::with('user')->find($id);

        if (!$vendor) {
            return $this->error('Vendor not found', 404);
        }

        $vendor->status = 'approved';
        $vendor->save();

        if ($vendor->user && $vendor->user->role !== 'admin') {
            $vendor->user->role = 'vendor';
            $vendor->user->save();
        }

        return $this->success($vendor, 'Vendor approved successfully.');
    }

    /**
     * Reject a vendor (admin only).
     * - set vendor->status = 'rejected'
     * - optionally set user->role back to 'user'
     */
    public function reject($id)
    {
        $vendor = Vendor::with('user')->find($id);

        if (!$vendor) {
            return $this->error('Vendor not found', 404);
        }

        $vendor->status = 'rejected';
        $vendor->save();

        if ($vendor->user && $vendor->user->role === 'vendor') {
            $vendor->user->role = 'user';
            $vendor->user->save();
        }

        return $this->success($vendor, 'Vendor rejected.');
    }

    public function products(Request $request, Vendor $vendor)
    {
        $perPage = (int) $request->query('per_page', 10);

        $products = $vendor->products()
            ->with('category')
            ->where('status', 'active')
            ->latest()
            ->paginate($perPage);

        return $this->paginated(
            $products,
            ProductResource::collection($products),
            'Vendor products'
        );
    }

    public function me(Request $request)
    {
        $vendor = $request->user()->vendor;

        if (!$vendor) {
            return $this->error('You do not have a vendor profile.', 404);
        }

        return $this->success(
            new VendorResource($vendor),
            'Your vendor profile'
        );
    }
}
