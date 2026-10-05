import '../../core/utils/json_utils.dart';
import '../models/lab.dart';
import 'api_client.dart';

/// CRUD laboratorium.
///
/// Membaca boleh siapa saja yang sudah masuk (kalender dan formulir pengajuan
/// membutuhkannya). Menambah, mengubah, dan menghapus hanya diizinkan server
/// untuk Kepala Laboratorium — lihat `LabPolicy` di backend.
class LabApi {
  LabApi({ApiClient? klien}) : _klien = klien ?? ApiClient();

  final ApiClient _klien;

  /// Daftar laboratorium.
  ///
  /// [termasukNonaktif] hanya berpengaruh untuk Kepala Laboratorium; pengguna
  /// lain selalu menerima laboratorium aktif saja.
  Future<List<Lab>> daftar({bool termasukNonaktif = false}) async {
    final respons = await _klien.get(
      '/labs',
      query: {if (termasukNonaktif) 'termasuk_nonaktif': '1'},
    );

    return Json.asMapList(Json.asMap(respons)['data'])
        .map(Lab.fromJson)
        .toList(growable: false);
  }

  /// Menambah (`id == 0`) atau mengubah laboratorium.
  Future<Lab> simpan(Lab lab) async {
    final respons = lab.id == 0
        ? await _klien.post('/labs', body: lab.toJson())
        : await _klien.put('/labs/${lab.id}', body: lab.toJson());

    return Lab.fromJson(Json.asMap(Json.asMap(respons)['data']));
  }

  /// Menghapus laboratorium.
  ///
  /// Server menolak dengan 409 bila laboratorium masih punya jadwal atau
  /// pengajuan — pesannya sudah siap ditampilkan lewat [AppException].
  Future<void> hapus(int id) => _klien.delete('/labs/$id');
}
