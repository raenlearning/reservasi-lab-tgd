/// Konfigurasi aplikasi.
///
/// Seluruh nilai yang perlu diubah saat berpindah lingkungan dikumpulkan di
/// sini, supaya tidak ada URL atau angka yang tersebar di dalam kode fitur.
class AppConfig {
  const AppConfig._();

  static const String appName = 'Reservasi Laboratorium';
  static const String institutionName = 'STMIK Triguna Dharma';
  static const String appVersion = '2.0.0';

  /// Kalimat penjelas singkat di bawah nama aplikasi pada layar masuk.
  static const String appTagline = 'Sistem Pengajuan Kelas Pengganti';

  // ===========================================================================
  // Aturan akun
  // ===========================================================================

  /// Panjang minimum kata sandi.
  ///
  /// Harus sinkron dengan aturan validasi di backend. Dipakai oleh
  /// [Validators.password] dan petunjuk pada formulir masuk/daftar.
  static const int minPasswordLength = 6;

  // ===========================================================================
  // Alamat backend
  // ===========================================================================

  /// Base URL Laravel API — **tanpa** garis miring di akhir.
  ///
  /// ## Cara memilih alamat yang benar
  ///
  /// | Cara menjalankan aplikasi | Alamat yang dipakai |
  /// |---------------------------|---------------------|
  /// | **Emulator Android** | `http://10.0.2.2:8000/api` |
  /// | **HP fisik di Wi-Fi yang sama** | `http://<IP-LAPTOP>:8000/api` |
  /// | **Chrome / desktop** | `http://127.0.0.1:8000/api` |
  ///
  /// ### Mengapa emulator memakai 10.0.2.2
  ///
  /// Emulator Android berjalan di dalam mesin virtual dengan jaringan
  /// tersendiri. `127.0.0.1` di dalam emulator menunjuk ke emulator itu
  /// sendiri, bukan ke laptop Anda. Android menyediakan alias khusus
  /// **`10.0.2.2`** yang diteruskan ke `127.0.0.1` milik laptop. Ini penyebab
  /// paling umum dari galat "Connection refused" saat pertama kali mencoba.
  ///
  /// ### Cara mengetahui IP laptop
  ///
  /// Windows (PowerShell): `ipconfig` — lihat *IPv4 Address* pada adapter Wi-Fi,
  /// misalnya `192.168.1.10`. HP dan laptop harus tersambung ke Wi-Fi yang sama.
  ///
  /// ### Mengubah nilai ini tanpa menyentuh kode
  ///
  /// ```bash
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api
  /// ```
  ///
  /// Cara ini lebih aman daripada mengedit berkas, karena tidak berisiko
  /// ikut ter-commit saat nilainya khusus untuk mesin Anda.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  /// Nama perangkat yang dicatat saat membuat token Sanctum. Memudahkan
  /// mencabut token tertentu tanpa mengeluarkan pengguna dari semua perangkat.
  static const String deviceName = 'flutter-android';

  // ===========================================================================
  // Jaringan
  // ===========================================================================

  /// Batas waktu satu permintaan HTTP.
  static const Duration requestTimeout = Duration(seconds: 15);

  // ===========================================================================
  // Polling
  // ===========================================================================

  /// Jeda antar-pemuatan-ulang kalender ketersediaan.
  ///
  /// Laravel + MySQL tidak punya padanan `snapshots()` milik Firestore, jadi
  /// pembaruan terjadwal dilakukan dengan *short polling*. Nilai ini
  /// menyeimbangkan kesegaran data dengan beban server:
  ///
  /// * **15 detik** — cukup segar untuk aplikasi kampus, dan satu siklus hanya
  ///   menghasilkan **satu** permintaan karena `/api/calendar` sudah
  ///   menggabungkan laboratorium, jadwal, dan keterisian dalam satu respons.
  /// * Terlalu kecil (2 detik) membebani server tanpa manfaat nyata.
  /// * Terlalu besar (> 60 detik) membuat perubahan jadwal terasa lambat.
  static const Duration pollingInterval = Duration(seconds: 15);

  // ===========================================================================
  // Aturan penjadwalan
  // ===========================================================================
  //
  // HARUS sama dengan `app/Support/Jadwal.php` di backend. Kalau salah satu
  // diubah, ubah keduanya — kalau tidak, klien akan mengira sebuah slot valid
  // sementara server menolaknya.

  /// Jam operasional laboratorium.
  static const int operatingHourStart = 8; // 08:00
  static const int operatingHourEnd = 21; // 21:00

  /// Durasi maksimum satu sesi kelas pengganti (menit).
  static const int maxSessionMinutes = 4 * 60;

  /// Batas hari ke depan yang boleh diajukan.
  static const int bookingHorizonDays = 60;

  /// Jarak antar-slot pada tampilan kalender (menit).
  static const int slotMinutes = 30;
}
