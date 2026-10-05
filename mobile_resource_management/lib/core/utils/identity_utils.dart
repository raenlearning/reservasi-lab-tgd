/// Utilitas NIM/NIDN.
///
/// Sejak autentikasi ditangani Laravel, NIM/NIDN dikirim apa adanya sebagai
/// `nomor_identitas`. Pemetaan ke email internal (warisan Firebase
/// Authentication yang mewajibkan email sebagai identifier) sudah tidak
/// diperlukan dan telah dihapus.
class IdentityUtils {
  const IdentityUtils._();

  static final RegExp _nimPattern = RegExp(r'^\d{6,15}$');
  static final RegExp _nidnPattern = RegExp(r'^\d{8,12}$');

  static String normalize(String nomorIdentitas) =>
      nomorIdentitas.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  static bool looksLikeNim(String value) =>
      _nimPattern.hasMatch(normalize(value));

  static bool looksLikeNidn(String value) =>
      _nidnPattern.hasMatch(normalize(value));

  static bool looksLikeIdentityNumber(String value) {
    final normalized = normalize(value);
    return _nimPattern.hasMatch(normalized) || _nidnPattern.hasMatch(normalized);
  }

  static String initials(String nama) {
    final parts = nama
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
