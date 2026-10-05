/// Daftar lokasi (path) navigasi aplikasi.
///
/// Dikumpulkan sebagai konstanta agar tidak ada salah ketik path dan supaya
/// `redirect` pada router mudah dibaca.
class Routes {
  const Routes._();

  // Gerbang & autentikasi

  /// Layar tunggu saat status sesi belum diketahui.
  static const String splash = '/';

  static const String login = '/masuk';
  static const String register = '/daftar';

  // Area Mahasiswa / Dosen

  static const String home = '/beranda';
  static const String calendar = '/kalender';
  static const String myBookings = '/pengajuan';
  static const String profile = '/profil';

  // Area Kepala Laboratorium

  static const String adminDashboard = '/admin/dasbor';
  static const String adminSchedule = '/admin/jadwal';
  static const String adminApproval = '/admin/verifikasi';
  static const String adminLab = '/admin/lab';
  static const String adminProfile = '/admin/profil';

  /// Prefiks seluruh area admin — dipakai untuk pemeriksaan peran pada router.
  static const String adminPrefix = '/admin';

  /// Halaman yang boleh diakses tanpa login.
  static const Set<String> publicRoutes = {splash, login, register};

  static bool isAdminArea(String location) => location.startsWith(adminPrefix);
}
