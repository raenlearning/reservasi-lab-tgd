import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import 'token_storage.dart';

/// Klien HTTP untuk Laravel API.
///
/// Menggantikan seluruh SDK Firebase. Tanggung jawabnya:
/// * menyisipkan header `Authorization: Bearer <token>` bila token tersedia,
/// * mengubah kode status HTTP menjadi [AppException] berbahasa Indonesia,
/// * menghapus token saat server menolaknya (401) sehingga aplikasi otomatis
///   kembali ke layar masuk.
///
/// Sengaja **tidak** menangani penyegaran token. Sanctum tidak menerbitkan
/// refresh token; masa berlaku diatur lewat `expiration` di
/// `config/sanctum.php`. Bila token kedaluwarsa, pengguna diminta masuk lagi.
class ApiClient {
  ApiClient({http.Client? klien, TokenStorage? tokenStorage})
    : _klien = klien ?? http.Client(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final http.Client _klien;
  final TokenStorage _tokenStorage;

  /// Dipanggil ketika server mengembalikan 401, supaya lapisan aplikasi dapat
  /// mengembalikan pengguna ke layar masuk.
  void Function()? onTidakTerautentikasi;

  Uri _uri(String path, [Map<String, String>? query]) {
    final bersih = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('${AppConfig.baseUrl}/$bersih');

    if (query == null || query.isEmpty) return uri;

    // Buang nilai kosong supaya tidak mengirim `?status=` yang akan ditolak
    // atau disalahartikan server.
    final terisi = Map.fromEntries(
      query.entries.where((e) => e.value.isNotEmpty),
    );

    return terisi.isEmpty ? uri : uri.replace(queryParameters: terisi);
  }

  Future<Map<String, String>> _headers() async {
    final token = await _tokenStorage.baca();

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ===========================================================================
  // Metode HTTP
  // ===========================================================================

  Future<Object?> get(String path, {Map<String, String>? query}) =>
      _kirim(() async => _klien.get(_uri(path, query), headers: await _headers()));

  Future<Object?> post(String path, {Object? body}) => _kirim(
    () async => _klien.post(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body ?? const {}),
    ),
  );

  Future<Object?> put(String path, {Object? body}) => _kirim(
    () async => _klien.put(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body ?? const {}),
    ),
  );

  Future<Object?> patch(String path, {Object? body}) => _kirim(
    () async => _klien.patch(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body ?? const {}),
    ),
  );

  Future<Object?> delete(String path) =>
      _kirim(() async => _klien.delete(_uri(path), headers: await _headers()));

  // ===========================================================================
  // Pemrosesan respons
  // ===========================================================================

  Future<Object?> _kirim(Future<http.Response> Function() aksi) async {
    late final http.Response respons;

    try {
      respons = await aksi().timeout(AppConfig.requestTimeout);
    } on TimeoutException catch (error, stackTrace) {
      throw AppException(
        AppErrorCode.timeout,
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      // SocketException / ClientException / HandshakeException semuanya berarti
      // "tidak bisa mencapai server" dari sudut pandang pengguna. Pesan
      // aslinya berbahasa Inggris dan teknis, jadi tidak ditampilkan apa adanya.
      throw AppException.from(error, stackTrace);
    }

    final body = _decode(respons.body);

    if (respons.statusCode >= 200 && respons.statusCode < 300) {
      return body;
    }

    if (respons.statusCode == 401) {
      // Token tidak lagi sah - bersihkan agar aplikasi tidak terus mencoba
      // memakai token mati, lalu beri tahu lapisan atas.
      await _tokenStorage.hapus();
      onTidakTerautentikasi?.call();
    }

    throw AppException.dariRespons(respons.statusCode, body);
  }

  Object? _decode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      // Server mengembalikan HTML (mis. halaman galat Laravel). Tidak ada yang
      // bisa diambil darinya, tetapi jangan sampai aplikasi crash karenanya.
      return null;
    }
  }

  void tutup() => _klien.close();
}
