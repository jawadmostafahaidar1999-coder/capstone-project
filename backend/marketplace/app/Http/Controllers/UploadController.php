<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class UploadController extends Controller
{
    public function store(Request $request)
    {
        $data = $request->validate([
            'file' => 'required|image|max:5120|mimes:jpg,jpeg,png,webp',
            'folder' => 'nullable|string',
        ]);

        $folder = trim($request->input('folder', 'uploads'), '/');
        $file = $request->file('file');

        // ✅ Verify image is readable
        $tmpPath = $file->getRealPath();
        $raw = @file_get_contents($tmpPath);
        if ($raw === false) {
            return response()->json(['success' => false, 'message' => 'Invalid image file.'], 422);
        }

        $img = @imagecreatefromstring($raw);
        if ($img === false) {
            return response()->json(['success' => false, 'message' => 'Corrupted image file.'], 422);
        }

        $w = imagesx($img);
        $h = imagesy($img);

        // ✅ Resize to max 1200px (huge speed win)
        $max = 1200;
        if ($w > $max || $h > $max) {
            $scale = min($max / $w, $max / $h);
            $newW = (int) round($w * $scale);
            $newH = (int) round($h * $scale);

            $resized = imagecreatetruecolor($newW, $newH);
            imagecopyresampled($resized, $img, 0, 0, 0, 0, $newW, $newH, $w, $h);
            imagedestroy($img);
            $img = $resized;
        }

        // ✅ Output as WEBP if supported, otherwise JPG
        $filenameBase = Str::random(40);
        $useWebp = function_exists('imagewebp');
        $filename = $useWebp ? "$filenameBase.webp" : "$filenameBase.jpg";
        $path = "$folder/$filename";

        ob_start();
        if ($useWebp) {
            imagewebp($img, null, 82); // quality 0-100
        } else {
            imagejpeg($img, null, 85);
        }
        $binary = ob_get_clean();

        imagedestroy($img);

        Storage::disk('public')->put($path, $binary);

        return response()->json([
            'success' => true,
            'data' => [
                'path' => "/storage/$path",
            ],
        ]);
    }
}
