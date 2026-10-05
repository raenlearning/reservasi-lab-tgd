/// Pembantu pembacaan nilai dari respons JSON hasil `jsonDecode`.
///
/// Sengaja berupa **static helper**, bukan extension method.
///
/// Extension method di Dart diselesaikan terhadap *tipe statis* penerima. Bila
/// tipe statisnya `dynamic`, Dart menganggap `dynamic` memiliki semua nama
/// anggota, sehingga tidak ada extension yang pernah diterapkan secara implisit
/// - pemanggilan jatuh ke dynamic dispatch dan gagal dengan `NoSuchMethodError`
/// saat runtime.
///
/// Contoh yang pernah menjatuhkan aplikasi ini:
///
/// ```dart
/// final map = respons.asMap;          // Map<String, dynamic>
/// AppUser.fromJson(map['user'].asMap) // map['user'] bertipe dynamic -> GAGAL
/// ```
///
/// Helper statis tidak punya masalah itu: argumen bertipe `dynamic` yang
/// dilewatkan ke parameter `Object?` hanyalah implicit cast yang selalu sah.
///
/// Berkas ini sengaja tidak mengimpor apa pun supaya dapat diuji dengan
/// `dart.exe` murni tanpa Flutter.
abstract final class Json {
  /// [nilai] sebagai map; `{}` bila bukan `Map<String, dynamic>` (termasuk null).
  static Map<String, dynamic> asMap(Object? nilai) =>
      nilai is Map<String, dynamic> ? nilai : const {};

  /// [nilai] sebagai list; `[]` bila bukan `List` (termasuk null).
  static List<dynamic> asList(Object? nilai) =>
      nilai is List ? nilai : const [];

  /// Daftar map dari [nilai].
  ///
  /// Merapikan pola `respons['data'].asList.map((e) => X.fromJson(e.asMap))`
  /// sekaligus menghilangkan `e` yang bertipe `dynamic` - penyebab kegagalan
  /// kedua selain index.
  ///
  /// Panjang daftar dipertahankan; elemen yang bukan map menjadi `{}`.
  static List<Map<String, dynamic>> asMapList(Object? nilai) =>
      asList(nilai).map(asMap).toList(growable: false);

  /// Bilangan bulat dari nilai JSON apa pun (num, string numerik, null).
  ///
  /// Lebih tahan banting daripada `(nilai as num?)?.toInt()` yang melempar
  /// `TypeError` bila server mengirim angka sebagai string.
  static int asInt(Object? nilai, {int fallback = 0}) =>
      asIntOrNull(nilai) ?? fallback;

  /// Seperti [asInt], tetapi mengembalikan `null` bila tidak dapat dibaca.
  static int? asIntOrNull(Object? nilai) {
    if (nilai is num) return nilai.toInt();
    return int.tryParse(nilai?.toString() ?? '');
  }
}
