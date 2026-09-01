<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\RegisterDevice;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceController extends Controller
{
    public function register(Request $request, RegisterDevice $register): JsonResponse
    {
        $validated = $request->validate([
            'device_uuid' => ['required', 'uuid'],
            'app' => ['required', 'string', 'max:24'],
            'platform' => ['nullable', 'string', 'max:32'],
            'app_version' => ['nullable', 'string', 'max:32'],
            'fcm_token' => ['nullable', 'string', 'max:512'],
        ]);

        $syncDevice = $register->handle($request->user(), $validated);

        return response()->json([
            'device_uuid' => $syncDevice->device_uuid,
            'last_pulled_seq' => $syncDevice->last_pulled_seq,
        ], 201);
    }
}
