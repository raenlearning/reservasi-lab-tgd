import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../services/auth_api.dart';
import '../services/booking_api.dart';
import '../services/kalender_api.dart';
import '../services/lab_api.dart';
import '../services/token_storage.dart';

/// Penyimpanan token — satu instance untuk seluruh aplikasi.
///
/// Sengaja dibuat tunggal: `ApiClient` dan `AuthApi` harus memakai penyimpanan
/// yang sama, kalau tidak token yang disimpan saat login tidak akan ditemukan
/// saat permintaan berikutnya dikirim.
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Klien HTTP bersama.
final apiClientProvider = Provider<ApiClient>((ref) {
  final klien = ApiClient(tokenStorage: ref.watch(tokenStorageProvider));
  ref.onDispose(klien.tutup);
  return klien;
});

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(
    klien: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  ),
);

final kalenderApiProvider = Provider<KalenderApi>(
  (ref) => KalenderApi(klien: ref.watch(apiClientProvider)),
);

final bookingApiProvider = Provider<BookingApi>(
  (ref) => BookingApi(klien: ref.watch(apiClientProvider)),
);

final jadwalApiProvider = Provider<JadwalApi>(
  (ref) => JadwalApi(klien: ref.watch(apiClientProvider)),
);

final labApiProvider = Provider<LabApi>(
  (ref) => LabApi(klien: ref.watch(apiClientProvider)),
);
