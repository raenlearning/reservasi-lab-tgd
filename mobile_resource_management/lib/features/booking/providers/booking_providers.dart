import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/enums.dart';
import '../../../data/providers/api_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../calendar/providers/calendar_providers.dart';

// =============================================================================
// Daftar pengajuan
// =============================================================================

/// Pengajuan yang dibuat pengguna yang sedang masuk.
///
/// Ikut disegarkan oleh polling kalender: setiap kali kalender memuat ulang,
/// provider ini di-`invalidate` supaya daftar pengajuan tidak menampilkan
/// status basi setelah Kepala Laboratorium memutuskan.
final pengajuanSayaProvider = FutureProvider<List<Booking>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];

  return ref.read(bookingApiProvider).daftar();
});

/// Pengajuan yang menunggu verifikasi — hanya untuk Kepala Laboratorium.
final pengajuanMenungguProvider = FutureProvider<List<Booking>>((ref) async {
  if (!ref.watch(isAdminProvider)) return const [];

  return ref
      .read(bookingApiProvider)
      .daftar(status: BookingStatus.menunggu.label);
});

/// Seluruh pengajuan — hanya untuk Kepala Laboratorium.
final semuaPengajuanProvider = FutureProvider<List<Booking>>((ref) async {
  if (!ref.watch(isAdminProvider)) return const [];

  return ref.read(bookingApiProvider).daftar();
});

/// Ringkasan jumlah pengajuan per status untuk pengguna yang sedang masuk.
final ringkasanPengajuanSayaProvider = Provider<Map<BookingStatus, int>>((ref) {
  final daftar = ref.watch(pengajuanSayaProvider).value ?? const [];

  final hasil = <BookingStatus, int>{
    for (final status in BookingStatus.values) status: 0,
  };
  for (final booking in daftar) {
    hasil[booking.status] = (hasil[booking.status] ?? 0) + 1;
  }
  return hasil;
});

/// Jadwal terdekat yang sudah disetujui, diurutkan dari yang paling dekat.
final jadwalTerdekatSayaProvider = Provider<List<Booking>>((ref) {
  final daftar = ref.watch(pengajuanSayaProvider).value ?? const [];

  final terdekat =
      daftar
          .where((b) => b.status.isDisetujui && !b.sudahLewat)
          .toList()
        ..sort((a, b) => a.tanggalDateTime.compareTo(b.tanggalDateTime));

  return terdekat;
});

// =============================================================================
// Aksi tulis
// =============================================================================

/// Aksi tulis pada pengajuan: mengajukan, memverifikasi, membatalkan.
///
/// State-nya hanya melacak **proses**. Daftar pengajuan tetap berasal dari
/// provider di atas, sehingga UI tidak berkedip ketika proses selesai tetapi
/// data terbaru belum sempat dimuat.
class BookingActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  bool get _sibuk => state.isLoading;

  /// Mengajukan reservasi baru.
  ///
  /// Mengembalikan `null` bila berhasil, atau pesan kesalahan siap-tampil bila
  /// gagal — termasuk pesan bentrok yang dikirim server.
  Future<String?> ajukan(BookingDraft draft) async {
    if (_sibuk) return null;
    state = const AsyncLoading<void>();

    try {
      await ref.read(bookingApiProvider).ajukan(draft);

      _segarkanSemua();
      state = const AsyncData<void>(null);

      return null;
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      return AppException.from(error).userMessage;
    }
  }

  /// Menyetujui atau menolak pengajuan. Hanya Kepala Laboratorium.
  Future<String?> verifikasi({
    required int bookingId,
    required bool disetujui,
    String? alasanPenolakan,
  }) async {
    if (_sibuk) return null;
    state = const AsyncLoading<void>();

    try {
      await ref
          .read(bookingApiProvider)
          .verifikasi(
            bookingId: bookingId,
            disetujui: disetujui,
            alasanPenolakan: alasanPenolakan,
          );

      _segarkanSemua();
      state = const AsyncData<void>(null);

      return null;
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      return AppException.from(error).userMessage;
    }
  }

  /// Membatalkan pengajuan yang masih menunggu.
  Future<String?> batalkan(int bookingId) async {
    if (_sibuk) return null;
    state = const AsyncLoading<void>();

    try {
      await ref.read(bookingApiProvider).batalkan(bookingId);

      _segarkanSemua();
      state = const AsyncData<void>(null);

      return null;
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      return AppException.from(error).userMessage;
    }
  }

  /// Menyegarkan seluruh data yang terpengaruh oleh perubahan pengajuan.
  ///
  /// Kalender ikut disegarkan karena status pengajuan menentukan apakah sebuah
  /// slot masih bisa diajukan.
  void _segarkanSemua() {
    ref
      ..invalidate(pengajuanSayaProvider)
      ..invalidate(pengajuanMenungguProvider)
      ..invalidate(semuaPengajuanProvider)
      ..invalidate(snapshotKalenderProvider);
  }

  void bersihkanError() => state = const AsyncData<void>(null);
}

final bookingActionControllerProvider =
    AsyncNotifierProvider<BookingActionController, void>(
      BookingActionController.new,
    );

/// Kode kesalahan dari aksi terakhir — dipakai UI untuk membedakan bentrok
/// jadwal dari kesalahan umum (mis. menyorot slot yang bertabrakan).
final bookingActionErrorCodeProvider = Provider<AppErrorCode?>((ref) {
  final state = ref.watch(bookingActionControllerProvider);
  final error = state.error;
  return error == null ? null : AppException.from(error).code;
});
