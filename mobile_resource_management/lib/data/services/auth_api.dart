import '../../core/errors/app_exception.dart';
import '../../core/utils/json_utils.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import 'api_client.dart';
import 'token_storage.dart';

/// Hasil login: token beserta profil pengguna.
class HasilLogin {
  const HasilLogin({required this.token, required this.user});

  final String token;
  final AppUser user;
}

/// Autentikasi berbasis token Sanctum.
///
/// Menggantikan `FirebaseAuth`. Perbedaan yang paling terasa: login memakai
/// **NIM/NIDN langsung**, tanpa perlu memetakannya ke email internal seperti
/// yang diwajibkan Firebase Authentication.
class AuthApi {
  AuthApi({ApiClient? klien, TokenStorage? tokenStorage})
    : _klien = klien ?? ApiClient(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _klien;
  final TokenStorage _tokenStorage;

  /// Dipanggil ketika token ditolak server (401) di permintaan mana pun.
  set onSesiBerakhir(void Function()? callback) =>
      _klien.onTidakTerautentikasi = callback;

  /// Masuk dan simpan token ke penyimpanan aman.
  Future<HasilLogin> masuk({
    required String nomorIdentitas,
    required String password,
    String? deviceName,
  }) async {
    final respons = await _klien.post(
      '/login',
      body: {
        'nomor_identitas': nomorIdentitas.trim(),
        'password': password,
        'device_name': ?deviceName,
      },
    );

    return _simpanHasil(respons);
  }

  /// Mendaftarkan akun Mahasiswa / Dosen baru.
  ///
  /// Server langsung menerbitkan token pada respons 201, sehingga pengguna
  /// tidak perlu mengetik ulang kredensialnya di layar masuk.
  ///
  /// [role] hanya boleh Mahasiswa atau Dosen — server menolak peran lain.
  Future<HasilLogin> daftar({
    required String nomorIdentitas,
    required String nama,
    required UserRole role,
    required String password,
    String? deviceName,
  }) async {
    final respons = await _klien.post(
      '/register',
      body: {
        'nomor_identitas': nomorIdentitas.trim(),
        'nama': nama.trim(),
        'jabatan': role.label,
        'password': password,
        // Laravel memakai aturan `confirmed`, yang mencocokkan field ini.
        'password_confirmation': password,
        'device_name': ?deviceName,
      },
    );

    return _simpanHasil(respons);
  }

  /// Membaca token dari respons, menyimpannya, lalu membentuk [HasilLogin].
  Future<HasilLogin> _simpanHasil(Object? respons) async {
    final map = Json.asMap(respons);
    final token = map['token']?.toString();

    if (token == null || token.isEmpty) {
      throw const AppException(
        AppErrorCode.unknown,
        message: 'Server tidak mengirim token. Hubungi administrator.',
      );
    }

    await _tokenStorage.simpan(token);

    return HasilLogin(
      token: token,
      user: AppUser.fromJson(Json.asMap(map['user'])),
    );
  }

  /// Mengambil profil pengguna yang sedang masuk.
  ///
  /// Mengembalikan `null` bila belum ada token — bukan galat, karena kondisi
  /// "belum login" adalah keadaan yang wajar saat aplikasi baru dibuka.
  Future<AppUser?> profil() async {
    if (!await _tokenStorage.adaToken) return null;

    final respons = await _klien.get('/me');

    // Respons `/me` dibungkus `data` oleh JsonResource Laravel.
    final Object? isi = Json.asMap(respons)['data'] ?? respons;

    return AppUser.fromJson(Json.asMap(isi));
  }

  /// Keluar: cabut token di server, lalu hapus dari perangkat.
  ///
  /// Token lokal tetap dihapus meskipun permintaan ke server gagal — kalau
  /// tidak, pengguna bisa terjebak dalam keadaan "tampak masih masuk" padahal
  /// tokennya sudah tidak berlaku.
  Future<void> keluar() async {
    try {
      await _klien.post('/logout');
    } catch (_) {
      // Diabaikan dengan sengaja — lihat komentar di atas.
    } finally {
      await _tokenStorage.hapus();
    }
  }

  Future<bool> get adaSesi => _tokenStorage.adaToken;
}
