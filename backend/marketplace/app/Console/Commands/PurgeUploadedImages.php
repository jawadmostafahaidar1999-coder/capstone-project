<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

// import your models
use App\Models\Vendor;
use App\Models\Product;
// use App\Models\Recipe;
// use App\Models\User;

class PurgeUploadedImages extends Command
{
    protected $signature = 'images:purge {--dry : Do not delete, just show what would happen}';
    protected $description = 'Delete uploaded images from storage and null image fields in DB';

    public function handle(): int
    {
        $dry = (bool) $this->option('dry');

        $pathsToDelete = [];

        $collect = function (?string $path) use (&$pathsToDelete) {
            if (!$path) return;

            // Convert "/storage/vendors/x.jpg" -> "vendors/x.jpg"
            $clean = ltrim(str_replace('/storage/', '', $path), '/');

            // Prevent dangerous deletions
            if ($clean === '' || str_contains($clean, '..')) return;

            $pathsToDelete[$clean] = true;
        };

        // Collect from tables
        Vendor::query()->whereNotNull('image')->pluck('image')->each(fn($p) => $collect($p));
        Product::query()->whereNotNull('image')->pluck('image')->each(fn($p) => $collect($p));
        // Recipe::query()->whereNotNull('image')->pluck('image')->each(fn($p) => $collect($p));
        // User::query()->whereNotNull('image')->pluck('image')->each(fn($p) => $collect($p));

        $paths = array_keys($pathsToDelete);
        $this->info('Unique files to delete: ' . count($paths));

        if ($dry) {
            foreach (array_slice($paths, 0, 30) as $p) $this->line($p);
            $this->warn('Dry run only. Nothing deleted.');
            return 0;
        }

        DB::transaction(function () use ($paths) {
            // Null DB references first (prevents broken references even if deletion fails mid-way)
            Vendor::query()->update(['image' => null]);
            Product::query()->update(['image' => null]);
            // Recipe::query()->update(['image' => null]);
            // User::query()->update(['image' => null]);

            // Then delete files
            Storage::disk('public')->delete($paths);
        });

        $this->info('Done. DB image fields nulled and files deleted.');
        return 0;
    }
}
