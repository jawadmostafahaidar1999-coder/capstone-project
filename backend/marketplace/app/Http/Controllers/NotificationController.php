<?php

namespace App\Http\Controllers;

use App\Http\Resources\NotificationResource;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();

        $only = (string) $request->query('only', 'all'); // all|unread|read
        $perPage = min(max((int) $request->query('per_page', 20), 1), 50);

        if ($only === 'unread') {
            $query = $user->unreadNotifications();
        } elseif ($only === 'read') {
            $query = $user->readNotifications();
        } else {
            $query = $user->notifications();
        }

        $page = $query->orderByDesc('created_at')->paginate($perPage);

        return response()->json([
            'success' => true,
            'message' => 'Notifications',
            'data' => [
                'items' => NotificationResource::collection(collect($page->items())),
                'meta' => [
                    'current_page' => $page->currentPage(),
                    'last_page' => $page->lastPage(),
                    'per_page' => $page->perPage(),
                    'total' => $page->total(),
                    'unread_count' => $user->unreadNotifications()->count(),
                ],
            ],
        ]);
    }

    public function unreadCount(Request $request)
    {
        $count = $request->user()->unreadNotifications()->count();

        return response()->json([
            'success' => true,
            'message' => 'Unread count',
            'data' => ['count' => $count],
        ]);
    }

    public function markRead(Request $request, string $id)
    {
        $n = $request->user()->notifications()->where('id', $id)->first();
        if (!$n) {
            return response()->json(['message' => 'Notification not found'], 404);
        }

        $n->markAsRead();

        return response()->json([
            'success' => true,
            'message' => 'Marked as read',
        ]);
    }

    public function markAllRead(Request $request)
    {
        $request->user()->unreadNotifications->markAsRead();

        return response()->json([
            'success' => true,
            'message' => 'All marked as read',
        ]);
    }

    public function destroy(Request $request, string $id)
    {
        $n = $request->user()->notifications()->where('id', $id)->first();
        if (!$n) {
            return response()->json(['message' => 'Notification not found'], 404);
        }

        $n->delete();

        return response()->json([
            'success' => true,
            'message' => 'Deleted',
        ]);
    }
}
