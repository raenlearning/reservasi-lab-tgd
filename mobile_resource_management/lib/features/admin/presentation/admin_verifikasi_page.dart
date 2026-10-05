import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/booking.dart';
import '../../booking/presentation/widgets/booking_card.dart';
import '../../booking/presentation/widgets/detail_pengajuan_sheet.dart';
import '../../booking/providers/booking_providers.dart';
import '../../calendar/providers/calendar_providers.dart';

/// Halaman verifikasi / approval pengajuan untuk Kepala Laboratorium.
///
/// Menampilkan pengajuan yang menunggu verifikasi beserta identitas pemohon,
/// lalu riwayat yang sudah final. Aksi Setujui/Tolak dijalankan lewat
/// `PATCH /api/bookings/{id}/review` — lihat [DetailPengajuanSheet].
class AdminVerifikasiPage extends ConsumerWidget {
  const AdminVerifikasiPage({super.key});

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
    final menungguAsync = ref.watch(pengajuanMenungguProvider);
    final semuaAsync = ref.watch(semuaPengajuanProvider);
    final namaLab = ref.watch(namaLabProvider);

    final sudahDiverifikasi =
        (semuaAsync.value ?? const <Booking>[])
            .where((booking) => booking.status.isFinal)
            .toList(growable: false)
          ..sort((a, b) {
            final aWaktu = a.reviewedAt ?? a.createdAt ?? DateTime(1970);
            final bWaktu = b.reviewedAt ?? b.createdAt ?? DateTime(1970);
            return bWaktu.compareTo(aWaktu);
          });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Verifikasi', style: theme.textTheme.titleLarge),
            Text(
              'Persetujuan pengajuan kelas pengganti',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(pengajuanMenungguProvider)
            ..invalidate(semuaPengajuanProvider);
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
                const InfoBanner(
                  tone: InfoBannerTone.info,
                  title: 'Cara memverifikasi',
                  message:
                      'Ketuk salah satu pengajuan untuk melihat rinciannya, '
                      'lalu pilih Setujui atau Tolak. Penolakan wajib disertai '
                      'alasan, dan pemohon akan menerima notifikasi otomatis.',
                ),
                const SizedBox(height: AppTheme.spaceLg),

                SectionHeader(
                  icon: Icons.pending_actions_rounded,
                  title: 'Menunggu verifikasi',
                  subtitle: 'Tinjau sebelum menyetujui',
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
                            'Semua pengajuan sudah diverifikasi. Pengajuan baru '
                            'akan muncul di sini dan Anda akan menerima '
                            'notifikasi.',
                      );
                    }
                    return Column(
                      children: [
                        for (final booking in data)
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

                const SizedBox(height: AppTheme.spaceLg),

                SectionHeader(
                  icon: Icons.history_rounded,
                  title: 'Riwayat verifikasi',
                  subtitle: '${sudahDiverifikasi.length} pengajuan',
                ),
                const SizedBox(height: AppTheme.spaceMd),

                if (sudahDiverifikasi.isEmpty)
                  const EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'Belum ada riwayat',
                    message:
                        'Pengajuan yang sudah Anda setujui atau tolak akan '
                        'tercatat di sini.',
                  )
                else
                  for (final booking in sudahDiverifikasi.take(20))
                    BookingCard(
                      booking: booking,
                      namaLab: namaLab[booking.idLab],
                      tampilkanPemohon: true,
                      onTap: () => _bukaDetail(context, ref, booking),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
