import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../data/models/booking.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../calendar/providers/calendar_providers.dart';
import '../../providers/booking_providers.dart';

/// Detail satu pengajuan, beserta aksi sesuai peran pengguna.
///
/// * Pemohon — dapat membatalkan selama status masih `Menunggu`.
/// * Kepala Laboratorium — dapat menyetujui atau menolak pengajuan `Menunggu`.
///
/// Mengembalikan `true` bila ada perubahan status yang berhasil disimpan.
class DetailPengajuanSheet extends ConsumerStatefulWidget {
  const DetailPengajuanSheet({super.key, required this.booking});

  final Booking booking;

  static Future<bool?> tampilkan(BuildContext context, Booking booking) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DetailPengajuanSheet(booking: booking),
    );
  }

  @override
  ConsumerState<DetailPengajuanSheet> createState() =>
      _DetailPengajuanSheetState();
}

class _DetailPengajuanSheetState extends ConsumerState<DetailPengajuanSheet> {
  bool _adaPerubahan = false;

  Booking get _booking => widget.booking;

  // ---------------------------------------------------------------------------
  // Aksi
  // ---------------------------------------------------------------------------

  Future<void> _setujui() async {
    final setuju = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Setujui pengajuan?'),
        content: Text(
          '${_booking.mataKuliah} pada '
          '${DateTimeUtils.formatTanggalPanjang(_booking.tanggalDateTime)} '
          '${_booking.rentangJam} akan disetujui. Slot ini menjadi terpakai '
          'dan pemohon akan menerima notifikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );

    if (setuju != true || !mounted) return;

    final pesan = await ref
        .read(bookingActionControllerProvider.notifier)
        .verifikasi(bookingId: _booking.id, disetujui: true);

    if (!mounted) return;
    if (pesan == null) {
      _adaPerubahan = true;
      _pesan('Pengajuan disetujui.', sukses: true);
      Navigator.of(context).pop(true);
    } else {
      _pesan(pesan);
    }
  }

  Future<void> _tolak() async {
    final alasan = await _dialogAlasanPenolakan();
    if (alasan == null || !mounted) return;

    final pesan = await ref
        .read(bookingActionControllerProvider.notifier)
        .verifikasi(
          bookingId: _booking.id,
          disetujui: false,
          alasanPenolakan: alasan,
        );

    if (!mounted) return;
    if (pesan == null) {
      _adaPerubahan = true;
      _pesan('Pengajuan ditolak.', sukses: true);
      Navigator.of(context).pop(true);
    } else {
      _pesan(pesan);
    }
  }

  Future<void> _batalkan() async {
    final setuju = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan pengajuan?'),
        content: const Text(
          'Pengajuan ini akan dihapus dan tidak dapat dikembalikan. Slot yang '
          'dipesan akan dilepas kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );

    if (setuju != true || !mounted) return;

    final pesan = await ref
        .read(bookingActionControllerProvider.notifier)
        .batalkan(_booking.id);

    if (!mounted) return;
    if (pesan == null) {
      _adaPerubahan = true;
      _pesan('Pengajuan dibatalkan.', sukses: true);
      Navigator.of(context).pop(true);
    } else {
      _pesan(pesan);
    }
  }

  /// Dialog pengisian alasan penolakan (wajib, minimal 5 karakter).
  Future<String?> _dialogAlasanPenolakan() {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Alasan penolakan'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alasan akan ditampilkan kepada pemohon beserta notifikasi.',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextFormField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText:
                      'Contoh: lab sudah digunakan untuk praktikum wajib',
                ),
                validator: (value) {
                  final teks = (value ?? '').trim();
                  if (teks.isEmpty) return 'Alasan penolakan wajib diisi.';
                  if (teks.length < 5) return 'Alasan minimal 5 karakter.';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
            child: const Text('Tolak pengajuan'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _pesan(String teks, {bool sukses = false}) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(teks),
          backgroundColor: sukses ? null : theme.colorScheme.error,
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final namaLab = ref.watch(namaLabProvider)[_booking.idLab] ?? 'Laboratorium';
    final isAdmin = ref.watch(isAdminProvider);
    final idPengguna = ref.watch(currentUserProvider)?.id;

    final sedangProses = ref.watch(
      bookingActionControllerProvider.select((state) => state.isLoading),
    );

    final bolehVerifikasi = isAdmin && _booking.status.isMenunggu;
    final bolehBatalkan =
        !isAdmin && idPengguna == _booking.idUser && _booking.bisaDibatalkan;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceLg,
            AppTheme.spaceMd,
            AppTheme.spaceLg,
            AppTheme.spaceLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---- Header ------------------------------------------------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _booking.mataKuliah,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  StatusBadge(status: _booking.status),
                  IconButton(
                    tooltip: 'Tutup',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(_adaPerubahan),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceMd),

              // ---- Rincian -----------------------------------------------
              _KartuRincian(
                baris: [
                  (
                    Icons.meeting_room_outlined,
                    'Laboratorium',
                    namaLab,
                  ),
                  (
                    Icons.event_outlined,
                    'Tanggal',
                    DateTimeUtils.formatTanggalPanjang(
                      _booking.tanggalDateTime,
                    ),
                  ),
                  (
                    Icons.schedule_outlined,
                    'Waktu',
                    '${_booking.rentangJam} · '
                    '${DateTimeUtils.formatDurasi(_booking.durasiMenit)}',
                  ),
                  if (_booking.namaPemohon != null)
                    (
                      Icons.person_outline_rounded,
                      'Pemohon',
                      _booking.nomorIdentitasPemohon == null
                          ? _booking.namaPemohon!
                          : '${_booking.namaPemohon} '
                                '(${_booking.nomorIdentitasPemohon})',
                    ),
                  if (_booking.createdAt != null)
                    (
                      Icons.history_rounded,
                      'Diajukan',
                      DateTimeUtils.formatTanggalPendek(_booking.createdAt!),
                    ),
                  if (_booking.reviewedAt != null)
                    (
                      Icons.verified_outlined,
                      'Diverifikasi',
                      DateTimeUtils.formatTanggalPendek(
                        _booking.reviewedAt!,
                      ),
                    ),
                ],
              ),

              // ---- Catatan -----------------------------------------------
              if (_booking.catatan != null) ...[
                const SizedBox(height: AppTheme.spaceMd),
                Text('Catatan pemohon', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(_booking.catatan!, style: theme.textTheme.bodyMedium),
              ],

              // ---- Alasan penolakan --------------------------------------
              if (_booking.status.isDitolak &&
                  _booking.alasanPenolakan != null) ...[
                const SizedBox(height: AppTheme.spaceMd),
                InfoBanner(
                  tone: InfoBannerTone.danger,
                  title: 'Alasan penolakan',
                  message: _booking.alasanPenolakan!,
                ),
              ],

              // ---- Konteks status ----------------------------------------
              const SizedBox(height: AppTheme.spaceLg),
              if (_booking.status.isMenunggu && !bolehVerifikasi && !bolehBatalkan)
                const InfoBanner(
                  tone: InfoBannerTone.info,
                  message:
                      'Pengajuan ini sedang menunggu verifikasi Kepala '
                      'Laboratorium. Anda akan menerima notifikasi begitu '
                      'statusnya berubah.',
                ),

              // ---- Aksi --------------------------------------------------
              if (bolehVerifikasi) ...[
                Text(
                  'Tindakan verifikasi',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppTheme.spaceSm + 2),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Tolak',
                        icon: Icons.close_rounded,
                        isLoading: sedangProses,
                        onPressed: _tolak,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm + 2),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Setujui',
                        icon: Icons.check_rounded,
                        isLoading: sedangProses,
                        onPressed: _setujui,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  'Persetujuan akan ditolak sistem bila ada pengajuan lain '
                  'yang sudah disetujui pada jam yang sama.',
                  style: theme.textTheme.bodySmall,
                ),
              ],

              if (bolehBatalkan) ...[
                SecondaryButton(
                  label: 'Batalkan pengajuan',
                  icon: Icons.delete_outline_rounded,
                  isLoading: sedangProses,
                  onPressed: _batalkan,
                ),
              ],

              if (_booking.status.isFinal) ...[
                Row(
                  children: [
                    Icon(
                      _booking.status.icon,
                      size: 16,
                      color: _booking.status.foreground,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _booking.status.isDisetujui
                            ? 'Pengajuan sudah disetujui dan slot tercatat '
                                  'terpakai pada kalender.'
                            : 'Pengajuan ditolak. Pemohon dapat mengajukan '
                                  'ulang pada slot waktu lain.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Daftar baris rincian dengan ikon.
class _KartuRincian extends StatelessWidget {
  const _KartuRincian({required this.baris});

  final List<(IconData, String, String)> baris;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: theme.dividerTheme.color!),
      ),
      child: Column(
        children: [
          for (var i = 0; i < baris.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(baris[i].$1, size: 16, color: theme.iconTheme.color),
                  const SizedBox(width: AppTheme.spaceSm + 2),
                  SizedBox(
                    width: 92,
                    child: Text(
                      baris[i].$2,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      baris[i].$3,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
            if (i != baris.length - 1)
              Divider(color: theme.dividerTheme.color, height: 1),
          ],
        ],
      ),
    );
  }
}
