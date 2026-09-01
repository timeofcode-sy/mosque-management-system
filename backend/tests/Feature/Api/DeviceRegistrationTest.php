<?php

namespace Tests\Feature\Api;

use App\Models\Device;
use App\Models\SyncDevice;
use Database\Seeders\RolesAndPermissionsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Concerns\BuildsApiActor;
use Tests\Concerns\BuildsInstitute;
use Tests\TestCase;

class DeviceRegistrationTest extends TestCase
{
    use BuildsApiActor, BuildsInstitute, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(RolesAndPermissionsSeeder::class);
        $this->buildInstitute();
    }

    public function test_registering_a_device_creates_a_sync_cursor(): void
    {
        $this->actingAsTeacher($this->institute);
        $deviceUuid = (string) Str::uuid7();

        $response = $this->postJson('/api/v1/devices/register', [
            'device_uuid' => $deviceUuid,
            'app' => 'teacher',
            'platform' => 'android',
            'app_version' => '1.0.0',
        ]);

        $response->assertCreated();
        $this->assertSame(1, SyncDevice::query()->where('device_uuid', $deviceUuid)->count());
        $this->assertSame(0, Device::query()->count());
    }

    public function test_registering_with_an_fcm_token_also_stores_a_push_device(): void
    {
        $this->actingAsTeacher($this->institute);

        $response = $this->postJson('/api/v1/devices/register', [
            'device_uuid' => (string) Str::uuid7(),
            'app' => 'teacher',
            'fcm_token' => 'fake-fcm-token',
        ]);

        $response->assertCreated();
        $this->assertSame(1, Device::query()->where('fcm_token', 'fake-fcm-token')->count());
    }

    public function test_registering_the_same_device_uuid_twice_updates_instead_of_duplicating(): void
    {
        $this->actingAsTeacher($this->institute);
        $deviceUuid = (string) Str::uuid7();

        $this->postJson('/api/v1/devices/register', ['device_uuid' => $deviceUuid, 'app' => 'teacher', 'app_version' => '1.0.0'])->assertCreated();
        $this->postJson('/api/v1/devices/register', ['device_uuid' => $deviceUuid, 'app' => 'teacher', 'app_version' => '1.1.0'])->assertCreated();

        $this->assertSame(1, SyncDevice::query()->where('device_uuid', $deviceUuid)->count());
        $this->assertSame('1.1.0', SyncDevice::query()->where('device_uuid', $deviceUuid)->sole()->app_version);
    }
}
