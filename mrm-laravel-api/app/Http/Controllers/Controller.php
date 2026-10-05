<?php

namespace App\Http\Controllers;

use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Foundation\Validation\ValidatesRequests;

/**
 * Controller dasar.
 *
 * `AuthorizesRequests` wajib ada agar `$this->authorize(...)` dapat memanggil
 * Policy. Di Laravel 11 ke atas trait ini tidak lagi dipasang otomatis pada
 * controller bawaan — melupakannya berarti Policy tidak pernah dijalankan, dan
 * pemeriksaan hak akses diam-diam terlewat.
 */
abstract class Controller
{
    use AuthorizesRequests, ValidatesRequests;
}
