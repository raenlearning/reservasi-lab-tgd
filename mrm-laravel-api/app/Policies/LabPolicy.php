<?php

namespace App\Policies;

use App\Models\User;

/**
 * Aturan akses data laboratorium.
 *
 * Semua pengguna terverifikasi boleh membaca daftar laboratorium (dibutuhkan
 * untuk mengisi kalender dan formulir pengajuan). Hanya Kepala Laboratorium
 * yang boleh mengubahnya.
 */
class LabPolicy
{
    public function viewAny(User $user): bool
    {
        return true;
    }

    public function view(User $user): bool
    {
        return true;
    }

    public function create(User $user): bool
    {
        return $user->isKepalaLab();
    }

    public function update(User $user): bool
    {
        return $user->isKepalaLab();
    }

    public function delete(User $user): bool
    {
        return $user->isKepalaLab();
    }
}
