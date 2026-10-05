<?php

namespace App\Policies;

use App\Models\User;

/**
 * Aturan akses jadwal laboratorium.
 *
 * Semua pengguna terverifikasi boleh membaca (kalender ketersediaan).
 * Hanya Kepala Laboratorium yang boleh menambah, mengubah, atau menghapus.
 */
class LabSchedulePolicy
{
    public function viewAny(User $user): bool
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
