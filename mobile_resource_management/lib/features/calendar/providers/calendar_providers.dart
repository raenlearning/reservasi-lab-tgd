import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/lab.dart';
import '../../../data/models/lab_schedule.dart';
import '../../../data/models/occupancy.dart';
import '../../../data/providers/api_providers.dart';
import '../../../data/services/kalender_api.dart';

// =============================================================================
// Rentang tanggal yang sedang ditampilkan
// =============================================================================

/// Rentang tanggal kalender, tanggal terpilih, dan filter laboratorium.
class RentangKalender {
  const RentangKalender({
    required this.bulan,
    this.tanggalTerpilih,
    this.labId,
  });

  /// Hari pertama bulan yang ditampilkan.
  final DateTime bulan;

  /// Tanggal yang detailnya sedang dibuka; `null` bila belum ada pilihan.
  final DateTime? tanggalTerpilih;

  /// Filter laboratorium; `null` berarti semua.
  final int? labId;

  String get kunciBulan => DateTimeUtils.toMonthKey(bulan);

  /// Contoh: `September 2026`.
  String get labelBulan => DateTimeUtils.formatNamaBulan(bulan);

  String get dari => DateTimeUtils.toDateKey(
    DateTimeUtils.firstDayOfMonth(kunciBulan),
  );

  String get sampai => DateTimeUtils.toDateKey(
    DateTimeUtils.lastDayOfMonth(kunciBulan),
  );

  /// Tanggal yang dipakai untuk daftar ketersediaan.
  ///
  /// Bila belum ada pilihan, atau pilihannya berada di bulan lain, dipakai hari
  /// pertama bulan yang ditampilkan — supaya daftar tidak pernah menunjuk
  /// tanggal di luar rentang yang sudah dimuat ([dari]..[sampai]).
  DateTime get tanggalEfektif {
    final pilihan = tanggalTerpilih;
    if (pilihan != null &&
        pilihan.year == bulan.year &&
        pilihan.month == bulan.month) {
      return pilihan;
    }
    return bulan;
  }

  /// [tanggalEfektif] sebagai `yyyy-MM-dd`.
  String get tanggalEfektifKey => DateTimeUtils.toDateKey(tanggalEfektif);

  RentangKalender copyWith({
    DateTime? bulan,
    int? labId,
    bool hapusLab = false,
  }) {
    return RentangKalender(
      bulan: bulan ?? this.bulan,
      tanggalTerpilih: tanggalTerpilih,
      labId: hapusLab ? null : (labId ?? this.labId),
    );
  }
}

class RentangKalenderController extends Notifier<RentangKalender> {
  @override
  RentangKalender build() => RentangKalender(
    bulan: DateTimeUtils.firstDayOfMonth(
      DateTimeUtils.toMonthKey(DateTimeUtils.today),
    ),
    tanggalTerpilih: DateTimeUtils.today,
  );

  /// Berpindah ke bulan milik [tanggal] **tanpa** memilih tanggalnya.
  ///
  /// Dipakai saat pengguna menggeser halaman kalender. Tanggal terpilih sengaja
  /// dikosongkan: kalau dibiarkan, daftar ketersediaan akan tetap menunjuk
  /// tanggal di bulan lama yang datanya sudah tidak dimuat.
  void tampilkanBulan(DateTime tanggal) {
    state = RentangKalender(
      bulan: DateTimeUtils.firstDayOfMonth(DateTimeUtils.toMonthKey(tanggal)),
      labId: state.labId,
    );
  }

  /// Menggeser bulan yang ditampilkan sebesar [delta] bulan.
  void geserBulan(int delta) {
    final kunciBaru = DateTimeUtils.geserBulan(
      DateTimeUtils.toMonthKey(state.bulan),
      delta,
    );
    tampilkanBulan(DateTimeUtils.parseDateKey('$kunciBaru-01'));
  }

  /// Memilih satu tanggal sekaligus menampilkan bulannya.
  void pilihTanggal(DateTime tanggal) {
    state = RentangKalender(
      bulan: DateTimeUtils.firstDayOfMonth(DateTimeUtils.toMonthKey(tanggal)),
      tanggalTerpilih: DateTimeUtils.dateOnly(tanggal),
      labId: state.labId,
    );
  }

  /// Kembali ke hari ini.
  void kembaliKeHariIni() => pilihTanggal(DateTimeUtils.today);

  void pilihLab(int? labId) {
    state = labId == null
        ? state.copyWith(hapusLab: true)
        : state.copyWith(labId: labId);
  }
}

final rentangKalenderProvider =
    NotifierProvider<RentangKalenderController, RentangKalender>(
      RentangKalenderController.new,
    );

// =============================================================================
// Status polling
// =============================================================================

/// Keterangan tentang siklus polling terakhir.
///
/// Dipisahkan dari data kalender supaya kegagalan sesaat **tidak** menghapus
/// data yang sudah tampil. Kalau galat polling langsung mengubah state menjadi
/// `AsyncError`, kalender akan kosong hanya karena satu permintaan gagal —
/// padahal data lama masih berguna.
class StatusPolling {
  const StatusPolling({
    this.terakhirSukses,
    this.galatTerakhir,
    this.sedangMenyegarkan = false,
  });

  final DateTime? terakhirSukses;
  final String? galatTerakhir;
  final bool sedangMenyegarkan;

  bool get adaGalat => galatTerakhir != null;

  StatusPolling copyWith({
    DateTime? terakhirSukses,
    String? galatTerakhir,
    bool hapusGalat = false,
    bool? sedangMenyegarkan,
  }) {
    return StatusPolling(
      terakhirSukses: terakhirSukses ?? this.terakhirSukses,
      galatTerakhir: hapusGalat ? null : (galatTerakhir ?? this.galatTerakhir),
      sedangMenyegarkan: sedangMenyegarkan ?? this.sedangMenyegarkan,
    );
  }
}

class StatusPollingController extends Notifier<StatusPolling> {
  @override
  StatusPolling build() => const StatusPolling();

  void catatSukses() => state = StatusPolling(
    terakhirSukses: DateTime.now(),
    sedangMenyegarkan: false,
  );

  void catatGalat(String pesan) => state = state.copyWith(
    galatTerakhir: pesan,
    sedangMenyegarkan: false,
  );

  void mulaiMenyegarkan() =>
      state = state.copyWith(sedangMenyegarkan: true);
}

final statusPollingProvider =
    NotifierProvider<StatusPollingController, StatusPolling>(
      StatusPollingController.new,
    );

// =============================================================================
// Snapshot kalender + short polling
// =============================================================================

/// Kalender ketersediaan dengan pembaruan berkala.
///
/// ## Mengapa polling
///
/// Firebase Firestore memberi pembaruan real-time lewat `snapshots()`.
/// Laravel + MySQL tidak punya padanannya, jadi pembaruan terjadwal dilakukan
/// dengan *short polling*: `Timer.periodic` memanggil ulang endpoint kalender
/// setiap [AppConfig.pollingInterval].
///
/// Beban server tetap wajar karena `/api/calendar` mengembalikan laboratorium,
/// jadwal, dan keterisian dalam **satu** respons — jadi satu siklus polling
/// hanya menghasilkan satu permintaan HTTP, bukan tiga.
///
/// ## Perilaku saat gagal
///
/// Kegagalan polling **tidak** mengubah data yang sedang tampil menjadi galat.
/// Data terakhir yang berhasil dimuat tetap ditampilkan, dan galatnya dicatat
/// di [statusPollingProvider] untuk ditampilkan sebagai penanda kecil. Kalau
/// setiap gangguan jaringan mengosongkan kalender, aplikasi akan terasa jauh
/// lebih rapuh daripada versi Firebase-nya.
class SnapshotKalenderController extends AsyncNotifier<SnapshotKalender> {
  Timer? _timer;

  @override
  Future<SnapshotKalender> build() async {
    final rentang = ref.watch(rentangKalenderProvider);

    // Setiap kali rentang berubah, build() dijalankan ulang. Timer lama harus
    // dibatalkan lebih dulu, kalau tidak akan ada dua polling berjalan
    // bersamaan dan permintaan menumpuk.
    ref.onDispose(_hentikanPolling);

    final data = await ref
        .read(kalenderApiProvider)
        .ambil(dari: rentang.dari, sampai: rentang.sampai);

    // Provider bisa sudah dibuang saat permintaan masih berjalan (mis. pengguna
    // keluar atau berpindah bulan). Menyentuh `ref` setelah itu melempar, dan
    // Timer yang sempat dimulai akan hidup tanpa pemilik.
    if (!ref.mounted) return data;

    ref.read(statusPollingProvider.notifier).catatSukses();
    _mulaiPolling();

    return data;
  }

  void _mulaiPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(AppConfig.pollingInterval, (_) => segarkanDiam());
  }

  void _hentikanPolling() {
    _timer?.cancel();
    _timer = null;
  }

  /// Memuat ulang tanpa menampilkan indikator loading.
  ///
  /// Dipakai oleh timer. Menampilkan `AsyncLoading` di sini akan membuat
  /// kalender berkedip setiap 15 detik.
  Future<void> segarkanDiam() async {
    final rentang = ref.read(rentangKalenderProvider);

    try {
      final data = await ref
          .read(kalenderApiProvider)
          .ambil(dari: rentang.dari, sampai: rentang.sampai);

      if (!ref.mounted) return;

      state = AsyncData(data);
      ref.read(statusPollingProvider.notifier).catatSukses();
    } catch (error) {
      if (!ref.mounted) return;

      ref
          .read(statusPollingProvider.notifier)
          .catatGalat(AppException.from(error).userMessage);
    }
  }

  /// Segarkan manual — dipakai tarik-untuk-menyegarkan.
  Future<void> segarkan() async {
    ref.read(statusPollingProvider.notifier).mulaiMenyegarkan();
    await segarkanDiam();
  }
}

final snapshotKalenderProvider =
    AsyncNotifierProvider<SnapshotKalenderController, SnapshotKalender>(
      SnapshotKalenderController.new,
    );

// =============================================================================
// Turunan dari snapshot
// =============================================================================

/// Daftar laboratorium.
final daftarLabProvider = Provider<List<Lab>>((ref) {
  return ref.watch(snapshotKalenderProvider).value?.labs ?? const [];
});

/// Peta `id lab` -> `nama lab`.
///
/// Dipakai agar daftar pengajuan bisa menampilkan nama laboratorium tanpa
/// permintaan tambahan per baris.
final namaLabProvider = Provider<Map<int, String>>((ref) {
  return {
    for (final lab in ref.watch(daftarLabProvider)) lab.id: lab.namaLab,
  };
});

/// Keterisian dikelompokkan per tanggal — untuk penanda di kalender bulanan.
final petaKeterisianProvider = Provider<Map<String, List<OccupancySlot>>>((ref) {
  final snapshot = ref.watch(snapshotKalenderProvider).value;
  if (snapshot == null) return const {};

  final namaLab = ref.watch(namaLabProvider);
  final peta = <String, List<OccupancySlot>>{};

  void tambah(OccupancySlot slot) {
    (peta[slot.tanggal] ??= []).add(slot);
  }

  for (final jadwal in snapshot.schedules) {
    if (jadwal.memblokirSlot) {
      tambah(
        OccupancySlot.fromSchedule(jadwal, namaLab: namaLab[jadwal.idLab]),
      );
    }
  }

  for (final booking in snapshot.bookings) {
    tambah(
      OccupancySlot.fromBooking(booking, namaLab: namaLab[booking.idLab]),
    );
  }

  return peta;
});

/// Ketersediaan per laboratorium pada satu tanggal.
final ketersediaanHariProvider =
    Provider.family<List<LabDayAvailability>, String>((ref, tanggal) {
      final labs = ref.watch(daftarLabProvider);
      final semua = ref.watch(petaKeterisianProvider)[tanggal] ?? const [];

      const jamBuka = AppConfig.operatingHourStart * 60;
      const jamTutup = AppConfig.operatingHourEnd * 60;

      return labs
          .map(
            (lab) => LabDayAvailability(
              idLab: lab.id,
              namaLab: lab.namaLab,
              tanggal: tanggal,
              slots: semua
                  .where((slot) => slot.idLab == lab.id)
                  .toList(growable: false),
              jamBukaMenit: jamBuka,
              jamTutupMenit: jamTutup,
            ),
          )
          .toList(growable: false);
    });

/// Ketersediaan **satu** laboratorium pada **satu** tanggal.
///
/// Dipakai formulir pengajuan untuk menampilkan slot kosong dan memberi
/// peringatan bentrok sebelum tombol kirim ditekan.
final ketersediaanLabTanggalProvider =
    Provider.family<LabDayAvailability?, ({int idLab, String tanggal})>(
      (ref, arg) {
        final daftar = ref.watch(ketersediaanHariProvider(arg.tanggal));

        for (final item in daftar) {
          if (item.idLab == arg.idLab) return item;
        }
        return null;
      },
    );

/// Seluruh laboratorium **termasuk yang nonaktif**.
///
/// Dipakai halaman kelola laboratorium. [daftarLabProvider] sengaja hanya
/// memuat laboratorium aktif (dari snapshot kalender), sehingga laboratorium
/// yang dinonaktifkan akan hilang dari sana dan tidak bisa diaktifkan kembali.
final semuaLabProvider = FutureProvider<List<Lab>>((ref) {
  return ref.read(labApiProvider).daftar(termasukNonaktif: true);
});

/// Jadwal acuan pada satu tanggal.
///
/// Dipakai halaman Jadwal Lab. Terpisah dari snapshot kalender karena halaman
/// itu dapat menelusuri tanggal di luar bulan yang sedang dibuka di kalender.
final jadwalHarianProvider =
    FutureProvider.family<List<LabSchedule>, String>((ref, tanggal) {
      return ref
          .read(jadwalApiProvider)
          .daftar(dari: tanggal, sampai: tanggal);
    });

/// Pengajuan pada satu tanggal.
final pengajuanHarianProvider =
    FutureProvider.family<List<Booking>, String>((ref, tanggal) {
      return ref.read(bookingApiProvider).daftar(tanggal: tanggal);
    });

/// Seluruh slot terpakai pada satu tanggal, diurutkan berdasarkan jam mulai.
///
/// Berbeda dari [petaKeterisianProvider], provider ini memuat **semua** tipe
/// jadwal acuan — termasuk tipe `Pengganti` yang tidak memblokir reservasi.
/// Halaman Jadwal Lab perlu menampilkan seluruhnya agar semuanya dapat diubah
/// atau dihapus.
final timelineHarianProvider =
    FutureProvider.family<List<OccupancySlot>, String>((ref, tanggal) async {
      final namaLab = ref.watch(namaLabProvider);
      final jadwal = await ref.watch(jadwalHarianProvider(tanggal).future);
      final pengajuan = await ref.watch(pengajuanHarianProvider(tanggal).future);

      final hasil = <OccupancySlot>[
        for (final item in jadwal)
          OccupancySlot.fromSchedule(item, namaLab: namaLab[item.idLab]),

        // Hanya pengajuan yang benar-benar menahan slot. Endpoint `/bookings`
        // mengembalikan seluruh status termasuk `Ditolak`, padahal pengajuan
        // yang ditolak sudah melepaskan slotnya. Kalau ikut ditampilkan, slot
        // yang sebenarnya kosong akan terlihat terisi.
        for (final item in pengajuan)
          if (item.menahanSlot)
            OccupancySlot.fromBooking(item, namaLab: namaLab[item.idLab]),
      ]..sort((a, b) => a.mulaiMenit.compareTo(b.mulaiMenit));

      return hasil;
    });

/// Filter laboratorium **khusus halaman Jadwal Lab** (Kepala Laboratorium).
///
/// Sengaja terpisah dari [rentangKalenderProvider]. Sebelumnya kedua halaman
/// berbagi satu filter, sehingga memilih "Lab Jaringan" di halaman Kalender
/// ikut menyembunyikan jadwal di halaman admin — dan sebaliknya. Gejalanya
/// menyesatkan: halaman tampak "tidak punya jadwal" padahal datanya ada.
final filterLabJadwalProvider =
    NotifierProvider<FilterLabJadwalController, int?>(
      FilterLabJadwalController.new,
    );

class FilterLabJadwalController extends Notifier<int?> {
  @override
  int? build() => null;

  /// `null` berarti seluruh laboratorium.
  void pilih(int? idLab) => state = idLab;
}

/// Jadwal acuan pada satu bulan (`yyyy-MM`).
///
/// Sengaja terpisah dari [snapshotKalenderProvider]: dasbor Kepala Laboratorium
/// harus selalu menampilkan angka bulan berjalan, bukan bulan yang sedang
/// ditelusuri pengguna di halaman kalender.
final jadwalBulanProvider = FutureProvider.family<List<LabSchedule>, String>((
  ref,
  bulanKey,
) {
  return ref
      .read(jadwalApiProvider)
      .daftar(
        dari: DateTimeUtils.toDateKey(
          DateTimeUtils.firstDayOfMonth(bulanKey),
        ),
        sampai: DateTimeUtils.toDateKey(DateTimeUtils.lastDayOfMonth(bulanKey)),
      );
});
