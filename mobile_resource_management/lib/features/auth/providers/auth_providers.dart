import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/enums.dart';
import '../../../data/providers/api_providers.dart';

/// Status sesi pengguna.
///
/// Dibuat sebagai `sealed class` supaya `switch` di router **wajib** menangani
/// ketiga kemungkinan. Kasus "belum masuk" mudah terlewat dan membuat pengguna
/// terjebak di layar kosong kalau tidak ditangani eksplisit.
sealed class AuthSession {
  const AuthSession();
}

class AuthMemuat extends AuthSession {
  const AuthMemuat();
}

class AuthBelumMasuk extends AuthSession {
  const AuthBelumMasuk();
}

class AuthMasuk extends AuthSession {
  const AuthMasuk(this.user);

  final AppUser user;
}

/// Sesi pengguna saat ini.
///
/// Dibaca sekali saat aplikasi dibuka: kalau token tersimpan masih sah,
/// `GET /api/me` mengembalikan profil dan pengguna langsung masuk tanpa perlu
/// mengetik kata sandi lagi.
class AuthSessionController extends AsyncNotifier<AuthSession> {
  @override
  Future<AuthSession> build() async {
    final auth = ref.watch(authApiProvider);

    // Saat server menolak token (401), ApiClient menghapusnya dan memanggil
    // callback ini. Sesi langsung diubah supaya router mengarahkan pengguna
    // kembali ke layar masuk — tanpa ini, aplikasi akan terus menampilkan
    // halaman yang setiap permintaannya gagal.
    auth.onSesiBerakhir = () {
      state = const AsyncData<AuthSession>(AuthBelumMasuk());
    };

    try {
      final user = await auth.profil();
      return user == null ? const AuthBelumMasuk() : AuthMasuk(user);
    } catch (error, stackTrace) {
      // Token ada tetapi ditolak — anggap belum masuk.
      if (error is AppException && error.code == AppErrorCode.unauthenticated) {
        return const AuthBelumMasuk();
      }

      // Galat jaringan tidak boleh membuat aplikasi menampilkan layar masuk
      // seolah-olah tokennya salah; pengguna diberi tahu lewat state error.
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Memuat ulang sesi — dipakai setelah login atau keluar.
  Future<void> muatUlang() async {
    state = const AsyncLoading<AuthSession>();
    state = await AsyncValue.guard(build);
  }
}

final authSessionProvider =
    AsyncNotifierProvider<AuthSessionController, AuthSession>(
      AuthSessionController.new,
    );

/// Pengguna yang sedang masuk, atau `null`.
final currentUserProvider = Provider<AppUser?>((ref) {
  final sesi = ref.watch(authSessionProvider).value;
  return sesi is AuthMasuk ? sesi.user : null;
});

/// Apakah pengguna saat ini Kepala Laboratorium.
final isAdminProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider)?.isAdmin ?? false,
);

/// Proses masuk/keluar.
///
/// Dipisahkan dari [authSessionProvider] supaya tombol bisa menampilkan spinner
/// tanpa mengubah identitas pengguna — kalau digabung, UI berkedip saat login
/// gagal.
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Masuk dengan NIM/NIDN dan kata sandi.
  ///
  /// Mengembalikan pesan kesalahan bila gagal, atau `null` bila berhasil.
  Future<String?> masuk({
    required String nomorIdentitas,
    required String password,
  }) async {
    state = const AsyncLoading<void>();

    try {
      await ref
          .read(authApiProvider)
          .masuk(
            nomorIdentitas: nomorIdentitas,
            password: password,
            deviceName: AppConfig.deviceName,
          );

      await ref.read(authSessionProvider.notifier).muatUlang();
      state = const AsyncData<void>(null);

      return null;
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      return AppException.from(error).userMessage;
    }
  }

  /// Mendaftarkan akun Mahasiswa / Dosen baru.
  ///
  /// Server menerbitkan token sekaligus, jadi pengguna langsung masuk setelah
  /// pendaftaran berhasil. Mengembalikan pesan kesalahan bila gagal, atau
  /// `null` bila berhasil.
  Future<String?> daftar({
    required String nomorIdentitas,
    required String nama,
    required UserRole role,
    required String password,
  }) async {
    state = const AsyncLoading<void>();

    try {
      await ref
          .read(authApiProvider)
          .daftar(
            nomorIdentitas: nomorIdentitas,
            nama: nama,
            role: role,
            password: password,
            deviceName: AppConfig.deviceName,
          );

      await ref.read(authSessionProvider.notifier).muatUlang();
      state = const AsyncData<void>(null);

      return null;
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      return AppException.from(error).userMessage;
    }
  }

  /// Keluar dan hapus token.
  Future<void> keluar() async {
    state = const AsyncLoading<void>();

    await ref.read(authApiProvider).keluar();
    await ref.read(authSessionProvider.notifier).muatUlang();

    state = const AsyncData<void>(null);
  }

  void bersihkanError() => state = const AsyncData<void>(null);
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

/// Jabatan yang boleh dipilih saat mendaftar.
///
/// Kepala Lab tidak termasuk — kalau boleh dipilih sendiri, siapa pun bisa
/// menaikkan hak aksesnya. Akun Kepala Lab dibuat lewat seeder di server.
const List<UserRole> jabatanYangBisaDidaftar = UserRole.selfRegistrable;
