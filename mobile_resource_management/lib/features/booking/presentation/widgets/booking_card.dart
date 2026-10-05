import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../data/models/booking.dart';

/// Kartu ringkasan satu pengajuan reservasi.
///
/// Dipakai ulang di Beranda, daftar pengajuan, dan dasbor Kepala Laboratorium.
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    this.namaLab,
    this.onTap,
    this.tampilkanPemohon = false,
  });

  final Booking booking;

  /// Nama laboratorium — diambil dari provider `namaLabProvider` agar tidak
  /// perlu pembacaan dokumen tambahan.
  final String? namaLab;

  final VoidCallback? onTap;

  /// Menampilkan identitas pemohon (dipakai pada tampilan Kepala Lab).
  final bool tampilkanPemohon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spaceSm + 2),
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: theme.dividerTheme.color!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    booking.mataKuliah,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                StatusBadge(status: booking.status, compact: true),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSm),

            _Baris(
              icon: Icons.meeting_room_outlined,
              teks: namaLab ?? 'Laboratorium',
            ),
            const SizedBox(height: 5),
            _Baris(
              icon: Icons.event_outlined,
              teks:
                  '${DateTimeUtils.formatTanggalPanjang(booking.tanggalDateTime)}'
                  ' · ${booking.rentangJam}',
            ),

            if (tampilkanPemohon && booking.namaPemohon != null) ...[
              const SizedBox(height: 5),
              _Baris(
                icon: Icons.person_outline_rounded,
                teks: booking.nomorIdentitasPemohon == null
                    ? booking.namaPemohon!
                    : '${booking.namaPemohon} '
                          '(${booking.nomorIdentitasPemohon})',
              ),
            ],

            if (booking.status.isDitolak &&
                booking.alasanPenolakan != null) ...[
              const SizedBox(height: AppTheme.spaceSm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE8E6),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  'Alasan penolakan: ${booking.alasanPenolakan}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFA32018),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({required this.icon, required this.teks});

  final IconData icon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: theme.iconTheme.color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            teks,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
