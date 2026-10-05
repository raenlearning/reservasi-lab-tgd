import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan token Sanctum.
///
/// Memakai `flutter_secure_storage`, bukan `shared_preferences`, karena token
/// ini setara dengan kata sandi: siapa pun yang membacanya bisa mengakses API
/// atas nama pengguna. Penyimpanan aman memakai Keychain (iOS) dan
/// Keystore/EncryptedSharedPreferences (Android).
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const String _kunciToken = 'sanctum_token';

  final FlutterSecureStorage _storage;

  Future<String?> baca() => _storage.read(key: _kunciToken);

  Future<void> simpan(String token) =>
      _storage.write(key: _kunciToken, value: token);

  /// Menghapus token saat keluar atau saat server menolaknya (401).
  Future<void> hapus() => _storage.delete(key: _kunciToken);

  Future<bool> get adaToken async => (await baca()) != null;
}
