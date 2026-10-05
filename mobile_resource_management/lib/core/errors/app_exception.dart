import 'dart:async';
import 'dart:io';

/// Kode kesalahan aplikasi yang netral terhadap backend.
///
/// Tujuannya: lapisan UI tidak perlu tahu soal kode status HTTP — cukup
/// menampilkan [AppException.userMessage].
enum AppErrorCode {
  unknown,
  network,
  timeout,
  cancelled,

  // Autentikasi & otorisasi
  invalidCredential,
  unauthenticated,
  permissionDenied,
  unauthorizedRole,
  userDisabled,
  tooManyRequests,

  // Umum
  notFound,
  alreadyExists,
  validation,
  conflict,
  failedPrecondition,
  unavailable,
  serverError,

  // Domain
  invalidTimeRange,
  outsideOperatingHours,
  scheduleConflict,
  pastDate,
}

/// Kesalahan aplikasi dengan pesan berbahasa Indonesia yang siap ditampilkan.
class AppException implements Exception {
  const AppException(
    this.code, {
    this.message,
    this.fieldErrors = const {},
    this.statusCode,
    this.cause,
    this.stackTrace,
  });

  final AppErrorCode code;
  final String? message;

  /// Galat per field dari respons 422 Laravel.
  ///
  /// Bentuknya `{'jam_mulai': ['Jadwal bentrok dengan ...']}`. Formulir dapat
  /// memakainya untuk menandai field yang bermasalah, bukan sekadar
  /// menampilkan satu snackbar.
  final Map<String, List<String>> fieldErrors;

  final int? statusCode;
  final Object? cause;
  final StackTrace? stackTrace;

  /// Pesan yang aman untuk ditampilkan ke pengguna.
  ///
  /// Untuk galat validasi, pesan field pertama lebih berguna daripada pesan
  /// umum "Data yang diberikan tidak valid" milik Laravel.
  String get userMessage {
    if (message != null && message!.isNotEmpty) return message!;

    // Laravel dapat mengirim `{"errors":{"field":[]}}` - daftar pesan kosong.
    // `.values.first.first` akan melempar `StateError: No element` justru pada
    // saat aplikasi sedang berusaha menampilkan pesan galat, sehingga galat asli
    // tertutupi oleh galat kedua.
    for (final pesanField in fieldErrors.values) {
      if (pesanField.isNotEmpty) return pesanField.first;
    }

    return messageFor(code);
  }

  /// Seluruh pesan field, digabung — untuk ditampilkan sekaligus.
  List<String> get semuaPesanField =>
      fieldErrors.values.expand((pesan) => pesan).toList(growable: false);

  bool get isValidationError => code == AppErrorCode.validation;

  /// Apakah kesalahan ini layak ditampilkan sebagai snackbar/dialog?
  bool get shouldReport => code != AppErrorCode.cancelled;

  static String messageFor(AppErrorCode code) {
    switch (code) {
      case AppErrorCode.unknown:
        return 'Terjadi kesalahan yang tidak terduga. Silakan coba lagi.';
      case AppErrorCode.network:
        return 'Tidak dapat terhubung ke server. Periksa koneksi dan pastikan '
            'alamat API sudah benar.';
      case AppErrorCode.timeout:
        return 'Server tidak merespons tepat waktu. Silakan coba lagi.';
      case AppErrorCode.cancelled:
        return 'Proses dibatalkan.';
      case AppErrorCode.invalidCredential:
        return 'NIM/NIDN atau kata sandi salah.';
      case AppErrorCode.unauthenticated:
        return 'Sesi Anda telah berakhir. Silakan masuk kembali.';
      case AppErrorCode.permissionDenied:
        return 'Anda tidak memiliki izin untuk melakukan tindakan ini.';
      case AppErrorCode.unauthorizedRole:
        return 'Fitur ini hanya dapat diakses oleh Kepala Laboratorium.';
      case AppErrorCode.userDisabled:
        return 'Akun Anda dinonaktifkan. Hubungi Kepala Laboratorium.';
      case AppErrorCode.tooManyRequests:
        return 'Terlalu banyak percobaan. Tunggu beberapa saat lalu coba lagi.';
      case AppErrorCode.notFound:
        return 'Data yang diminta tidak ditemukan.';
      case AppErrorCode.alreadyExists:
        return 'Data tersebut sudah ada.';
      case AppErrorCode.validation:
        return 'Data yang dikirim belum lengkap atau tidak valid.';
      case AppErrorCode.conflict:
        return 'Permintaan bertabrakan dengan data yang sudah ada.';
      case AppErrorCode.failedPrecondition:
        return 'Permintaan tidak dapat diproses pada kondisi saat ini.';
      case AppErrorCode.unavailable:
        return 'Layanan sedang tidak tersedia. Silakan coba beberapa saat lagi.';
      case AppErrorCode.serverError:
        return 'Terjadi gangguan di server. Silakan coba lagi nanti.';
      case AppErrorCode.invalidTimeRange:
        return 'Jam selesai harus lebih besar daripada jam mulai.';
      case AppErrorCode.outsideOperatingHours:
        return 'Jam yang dipilih di luar jam operasional laboratorium.';
      case AppErrorCode.scheduleConflict:
        return 'Jadwal tersebut sudah terpakai. Silakan pilih slot waktu lain.';
      case AppErrorCode.pastDate:
        return 'Tanggal yang dipilih sudah lewat.';
    }
  }

  /// Memetakan kesalahan apa pun (HTTP, jaringan, timeout) menjadi [AppException].
  factory AppException.from(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) return error;

    if (error is TimeoutException) {
      return AppException(
        AppErrorCode.timeout,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is SocketException || error is HttpException) {
      return AppException(
        AppErrorCode.network,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return AppException(
      AppErrorCode.unknown,
      message: error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }

  /// Memetakan kode status HTTP Laravel menjadi [AppException].
  ///
  /// [body] adalah isi respons yang sudah di-decode. Laravel mengembalikan
  /// `{"message": "...", "errors": {...}}` untuk galat validasi, dan
  /// `{"message": "..."}` untuk galat lainnya.
  factory AppException.dariRespons(int statusCode, Object? body) {
    final map = body is Map ? body : const {};
    final pesan = map['message']?.toString();
    final fieldErrors = _bacaFieldErrors(map['errors']);

    return AppException(
      _kodeDariStatus(statusCode, fieldErrors),
      message: fieldErrors.isEmpty ? pesan : null,
      fieldErrors: fieldErrors,
      statusCode: statusCode,
    );
  }

  static AppErrorCode _kodeDariStatus(
    int statusCode,
    Map<String, List<String>> fieldErrors,
  ) {
    switch (statusCode) {
      case 401:
        return AppErrorCode.unauthenticated;
      case 403:
        return AppErrorCode.unauthorizedRole;
      case 404:
        return AppErrorCode.notFound;
      case 409:
        return AppErrorCode.conflict;
      case 422:
        // Laravel memakai 422 untuk dua hal: validasi bentuk, dan penolakan
        // bentrok jadwal dari controller. Keduanya perlu dibedakan agar UI
        // dapat menyorot slot yang bertabrakan, bukan sekadar menampilkan
        // galat pada field.
        return _terlihatSepertiBentrok(fieldErrors)
            ? AppErrorCode.scheduleConflict
            : AppErrorCode.validation;
      case 429:
        return AppErrorCode.tooManyRequests;
      case 500:
      case 502:
      case 503:
      case 504:
        return AppErrorCode.serverError;
      default:
        return AppErrorCode.unknown;
    }
  }

  /// Mendeteksi pesan bentrok dari controller.
  ///
  /// Controller mengirim pesan yang selalu memuat kata "bentrok" pada galat
  /// `jam_mulai`. Pencocokan teks memang rapuh, tetapi alternatifnya adalah
  /// memakai kode galat khusus di sisi server — dan itu belum sepadan untuk
  /// satu kasus ini.
  static bool _terlihatSepertiBentrok(Map<String, List<String>> fieldErrors) {
    final pesanJam = fieldErrors['jam_mulai'];
    if (pesanJam == null) return false;
    return pesanJam.any((p) => p.toLowerCase().contains('bentrok'));
  }

  static Map<String, List<String>> _bacaFieldErrors(Object? mentah) {
    if (mentah is! Map) return const {};

    final hasil = <String, List<String>>{};
    mentah.forEach((kunci, nilai) {
      if (nilai is List) {
        hasil[kunci.toString()] =
            nilai.map((e) => e.toString()).toList(growable: false);
      } else if (nilai != null) {
        hasil[kunci.toString()] = [nilai.toString()];
      }
    });
    return hasil;
  }

  @override
  String toString() => 'AppException(${code.name}): $userMessage';
}
