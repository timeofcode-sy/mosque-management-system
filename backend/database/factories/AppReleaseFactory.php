<?php

namespace Database\Factories;

use App\Enums\AppTarget;
use App\Models\AppRelease;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<AppRelease>
 */
class AppReleaseFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $build = fake()->unique()->numberBetween(2, 900);

        return [
            'target' => AppTarget::Mobile,
            'version' => "1.0.0-beta.{$build}",
            'build_number' => $build,
            'title' => null,
            'notes' => "تحسيناتٌ في الأداء.\nإصلاحاتٌ صغيرة.",
            'is_mandatory' => false,
            'external_url' => "https://downloads.example.com/nuzuln-{$build}.apk",
            'published_at' => now()->subMinute(),
        ];
    }

    public function draft(): static
    {
        return $this->state(fn () => ['published_at' => null]);
    }

    public function mandatory(): static
    {
        return $this->state(fn () => ['is_mandatory' => true]);
    }

    public function target(AppTarget $target): static
    {
        return $this->state(fn () => ['target' => $target]);
    }

    public function build(int $build, ?string $version = null): static
    {
        return $this->state(fn () => ['build_number' => $build, 'version' => $version ?? "1.0.0-beta.{$build}"]);
    }
}
