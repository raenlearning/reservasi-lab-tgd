<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreLabRequest;
use App\Http\Resources\LabResource;
use App\Models\Lab;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * Data laboratorium.
 *
 * Membaca boleh siapa saja yang sudah masuk (kalender dan formulir pengajuan
 * membutuhkannya). Mengubah hanya Kepala Laboratorium.
 */
class LabController extends Controller
{
    /**
     * GET /api/labs?termasuk_nonaktif=1
     *
     * Secara bawaan hanya laboratorium aktif yang dikembalikan, supaya tidak
     * muncul sebagai pilihan di formulir pengajuan. Kepala Laboratorium dapat
     * meminta seluruhnya untuk keperluan pengelolaan.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorize('viewAny', Lab::class);

        $mintaSemua = $request->boolean('termasuk_nonaktif')
            && $request->user()->isKepalaLab();

        return LabResource::collection(
            Lab::query()
                ->when(! $mintaSemua, fn ($q) => $q->aktif())
                ->orderBy('nama_lab')
                ->get()
        );
    }

    /**
     * GET /api/labs/{lab}
     */
    public function show(Lab $lab): LabResource
    {
        $this->authorize('view', Lab::class);

        return new LabResource($lab);
    }

    /**
     * POST /api/labs
     */
    public function store(StoreLabRequest $request): JsonResponse
    {
        $this->authorize('create', Lab::class);

        $lab = Lab::create($request->validated());

        return (new LabResource($lab))->response()->setStatusCode(201);
    }

    /**
     * PUT /api/labs/{lab}
     */
    public function update(StoreLabRequest $request, Lab $lab): LabResource
    {
        $this->authorize('update', Lab::class);

        $lab->update($request->validated());

        return new LabResource($lab->fresh());
    }

    /**
     * DELETE /api/labs/{lab}
     *
     * Laboratorium yang masih punya jadwal atau pengajuan tidak dapat dihapus —
     * foreign key `restrictOnDelete` akan menolaknya. Pesan galatnya
     * diterjemahkan agar bisa ditindaklanjuti.
     */
    public function destroy(Lab $lab): JsonResponse
    {
        $this->authorize('delete', Lab::class);

        if ($lab->schedules()->exists() || $lab->bookings()->exists()) {
            return response()->json([
                'message' => 'Laboratorium ini masih memiliki jadwal atau pengajuan. '
                    .'Nonaktifkan saja agar riwayat tetap utuh.',
            ], 409);
        }

        $lab->delete();

        return response()->json(['message' => 'Laboratorium dihapus.']);
    }
}
