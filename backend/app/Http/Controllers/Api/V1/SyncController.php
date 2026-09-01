<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\SyncPull;
use App\Actions\SyncPush;
use App\Http\Controllers\Controller;
use App\Http\Resources\V1\ChangeLogResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SyncController extends Controller
{
    public function pull(Request $request, SyncPull $sync): JsonResponse
    {
        $validated = $request->validate([
            'since' => ['nullable', 'integer', 'min:0'],
            'app' => ['required', 'string', 'max:24'],
            'device_uuid' => ['nullable', 'uuid'],
        ]);

        $result = $sync->handle(
            $request->user(),
            (int) ($validated['since'] ?? 0),
            $validated['app'],
            $validated['device_uuid'] ?? null,
        );

        return response()->json([
            'server_seq' => $result['server_seq'],
            'changes' => ChangeLogResource::collection($result['changes']),
        ]);
    }

    public function push(Request $request, SyncPush $sync): JsonResponse
    {
        $request->validate([
            'device_uuid' => ['nullable', 'uuid'],
            'operations' => ['required', 'array', 'min:1'],
            'operations.*.op_uuid' => ['required', 'uuid'],
            'operations.*.type' => ['required', 'string'],
        ]);

        $result = $sync->handle(
            $request->user(),
            $request->input('operations'),
            $request->input('device_uuid'),
        );

        return response()->json($result);
    }
}
