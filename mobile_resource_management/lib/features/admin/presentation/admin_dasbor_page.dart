import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/enums.dart';
import '../../auth/providers/auth_providers.dart';
import '../../booking/presentation/widgets/booking_card.dart';
import '../../booking/presentation/widgets/detail_pengajuan_sheet.dart';
import '../../booking/providers/booking_providers.dart';
import '../../calendar/providers/calendar_providers.dart';

/// Dasbor Kepala Laboratorium.
class AdminDasborPage extends ConsumerWidget {
  const AdminDasborPage({super.key});

  Future<void> _bukaDetail(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
  ) async {
    final berubah = await DetailPengajuanSheet.tampilkan(context, booking);
    if (berubah != true) return;
    ref
      ..invalidate(pengajuanMenungguProvider)
      ..invalidate(semuaPengajuanProvider)
      ..invalidate(petaKeterisianProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final semuaAsync = ref.watch(semuaPengajuanProvider);
    final menungguAsync = ref.watch(pengajuanMenungguProvider);
    final namaLab = ref.watch(namaLabProvider);

    final bulanIni = DateTimeUtils.toMonthKey(DateTimeUtils.today);
    final jadwalAsync = ref.watch(jadwalBulanProvider(bulanIni));

    final semua = semuaAsync.value ?? const <Booking>[];
    final menunggu = menungguAsync.value ?? const <Booking>[];
    final jumlahJadwal = jadwalAsync.value?.length ?? 0;

    final jumlahDisetujui = semua.where((b) => b.status.isDisetujui).length;
    final jumlahDitolak = semua.where((b) => b.status.isDitolak).length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Dasbor Kepala Lab', style: theme.textTheme.titleLarge),
            Text(
              user?.nama ?? '-',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(semuaPengajuanProvider)
            ..invalidate(pengajuanMenungguProvider)
            ..invalidate(jadwalBulanProvider);
          await Future<void>.delayed(const Duration(milliseconds: 300));
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                AppTheme.spaceSm,
                20,
                AppTheme.spaceXl,
              ),
              children: [
                // ---- Ringkasan 
                const SectionHeader(
                  icon: Icons.dashboard_outlined,
                  title: 'Ringkasan',
                  subtitle: 'Kondisi pengajuan & jadwal laboratorium',
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Perlu verifikasi',
                        value: '${menunggu.length}',
                        icon: Icons.pending_actions_rounded,
                        color: BookingStatus.menunggu.foreground,
                        onTap: () => context.go(Routes.adminApproval),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm + 2),
                    Expanded(
                      child: StatCard(
                        label: 'Disetujui',
                        value: '$jumlahDisetujui',
                        icon: BookingStatus.disetujui.icon,
                        color: BookingStatus.disetujui.foreground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSm + 2),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Ditolak',
                        value: '$jumlahDitolak',
                        icon: BookingStatus.ditolak.icon,
                        color: BookingStatus.ditolak.foreground,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm + 2),
                    Expanded(
                      child: StatCard(
                        label: 'Jadwal bulan ini',
                        value: '$jumlahJadwal',
                        icon: Icons.event_available_outlined,
                        color: theme.colorScheme.secondary,
                        onTap: () => context.go(Routes.adminSchedule),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spaceLg),

                // ---- Aksi cepat 
                const SectionHeader(
                  icon: Icons.bolt_outlined,
                  title: 'Aksi cepat',
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: _AksiCepat(
                        icon: Icons.edit_calendar_outlined,
                        label: 'Jadwal',
                        onTap: () => context.go(Routes.adminSchedule),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm + 2),
                    Expanded(
                      child: _AksiCepat(
                        icon: Icons.fact_check_outlined,
                        label: 'Verifikasi',
                        onTap: () => context.go(Routes.adminApproval),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm + 2),
                    Expanded(
                      child: _AksiCepat(
                        icon: Icons.meeting_room_outlined,
                        label: 'Kelola lab',
                        onTap: () => context.push(Routes.adminLab),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spaceLg),

                // ---- Menunggu verifikasi ---------------------------------
                SectionHeader(
                  icon: Icons.pending_actions_rounded,
                  title: 'Menunggu verifikasi',
                  subtitle: '${menunggu.length} pengajuan',
                  trailingLabel: menunggu.isEmpty ? null : 'Lihat semua',
                  onTrailingTap: menunggu.isEmpty
                      ? null
                      : () => context.go(Routes.adminApproval),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                AsyncValueView(
                  value: menungguAsync,
                  compact: true,
                  onRetry: () => ref.invalidate(pengajuanMenungguProvider),
                  builder: (data) {
                    if (data.isEmpty) {
                      return const EmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'Tidak ada pengajuan baru',
                        message:
                            'Semua pengajuan sudah diverifikasi. Pengajuan '
                            'baru dari Mahasiswa/Dosen akan muncul di sini.',
                      );
                    }
                    return Column(
                      children: [
                        for (final booking in data.take(3))
                          BookingCard(
                            booking: booking,
                            namaLab: namaLab[booking.idLab],
                            tampilkanPemohon: true,
                            onTap: () => _bukaDetail(context, ref, booking),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AksiCepat extends StatelessWidget {
  const _AksiCepat({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceMd,
        ),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: theme.dividerTheme.color!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.primary),
            const SizedBox(height: AppTheme.spaceSm),
            Text(label, style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}
