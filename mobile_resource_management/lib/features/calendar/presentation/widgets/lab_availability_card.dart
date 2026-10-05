import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/date_time_utils.dart';
import '../../../../../data/models/occupancy.dart';

/// Kartu ketersediaan satu laboratorium pada tanggal terpilih.
class LabAvailabilityCard extends StatelessWidget {
  const LabAvailabilityCard({
    super.key,
    required this.availability,
    this.onAjukan,
  });

  final LabDayAvailability availability;

  /// Membuka formulir pengajuan dengan lab & tanggal kartu ini.
  ///
  /// `null` bila pengguna tidak berhak mengajukan (mis. Kepala Laboratorium).
  final VoidCallback? onAjukan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kosong = availability.rentangKosong;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
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
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  Icons.desktop_windows_outlined,
                  size: 19,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      availability.namaLab,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      availability.penuh
                          ? 'Tidak ada slot kosong'
                          : '${kosong.length} slot kosong · '
                                '${DateTimeUtils.formatDurasi(availability.totalMenitKosong)} '
                                'tersedia',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _StatusPill(penuh: availability.penuh),
            ],
          ),

          if (availability.slots.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceMd),
            const _SubJudul(teks: 'Sudah terpakai'),
            const SizedBox(height: AppTheme.spaceSm),
            ...availability.slots.map(
              (slot) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: OccupancyTile(slot: slot),
              ),
            ),
          ],

          const SizedBox(height: AppTheme.spaceSm + 4),
          const _SubJudul(teks: 'Slot tersedia'),
          const SizedBox(height: AppTheme.spaceSm),
          if (kosong.isEmpty)
            Text(
              'Tidak ada slot tersisa pada jam operasional '
              '(${availability.jamBukaMenit ~/ 60}:00 – '
              '${availability.jamTutupMenit ~/ 60}:00).',
              style: theme.textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final rentang in kosong)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2F5EA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      rentang.label,
                      style: const TextStyle(
                        color: Color(0xFF14653C),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),

          if (onAjukan != null) ...[
            const SizedBox(height: AppTheme.spaceMd),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: availability.penuh ? null : onAjukan,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: Text(
                  availability.penuh
                      ? 'Tidak ada slot tersisa'
                      : 'Ajukan kelas pengganti',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.penuh});

  final bool penuh;

  @override
  Widget build(BuildContext context) {
    final foreground = penuh
        ? const Color(0xFFA32018)
        : const Color(0xFF14653C);
    final background = penuh
        ? const Color(0xFFFCE8E6)
        : const Color(0xFFE2F5EA);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        penuh ? 'Penuh' : 'Tersedia',
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SubJudul extends StatelessWidget {
  const _SubJudul({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Text(
      teks.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 0.6,
      ),
    );
  }
}

/// Satu baris slot waktu terpakai pada kartu ketersediaan.
class OccupancyTile extends StatelessWidget {
  const OccupancyTile({super.key, required this.slot});

  final OccupancySlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warna = slot.source.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border(
          left: BorderSide(color: warna, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(slot.source.icon, size: 15, color: warna),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.judul,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  [
                    slot.source.label,
                    if (slot.subjudul != null) slot.subjudul!,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Text(
            slot.rentangJam,
            style: theme.textTheme.labelMedium?.copyWith(color: warna),
          ),
        ],
      ),
    );
  }

}
