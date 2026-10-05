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
import '../../booking/presentation/widgets/form_pengajuan_sheet.dart';
import '../../booking/providers/booking_providers.dart';
import '../../calendar/providers/calendar_providers.dart';

/// Beranda Mahasiswa / Dosen.
class BerandaPage extends ConsumerWidget {
  const BerandaPage({super.key});

  static String _sapaan(int jam) {
    if (jam < 11) return 'Selamat pagi';
    if (jam < 15) return 'Selamat siang';
    if (jam < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  Future<void> _bukaDetail(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
  ) async {
    final berubah = await DetailPengajuanSheet.tampilkan(context, booking);
    if (berubah == true) ref.invalidate(pengajuanSayaProvider);
  }

  Future<void> _bukaFormPengajuan(BuildContext context, WidgetRef ref) async {
    final terkirim = await FormPengajuanSheet.tampilkan(context);
    if (terkirim != true || !context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Pengajuan terkirim. Menunggu verifikasi Kepala Laboratorium.',
          ),
        ),
      );
    ref.invalidate(pengajuanSayaProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final ringkasan = ref.watch(ringkasanPengajuanSayaProvider);
    final pengajuanAsync = ref.watch(pengajuanSayaProvider);
    final jadwalTerdekat = ref.watch(jadwalTerdekatSayaProvider);
    final namaLab = ref.watch(namaLabProvider);

    final daftar = pengajuanAsync.value ?? const [];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${_sapaan(DateTime.now().hour)}, '
              '${user?.nama.split(' ').first ?? 'Pengguna'}',
              style: theme.textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              DateTimeUtils.formatTanggalPanjang(DateTime.now()),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(pengajuanSayaProvider)
            ..invalidate(daftarLabProvider);
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
                // ---- Kartu identitas -------------------------------------
                _KartuIdentitas(
                  nama: user?.nama ?? '-',
                  nomorIdentitas: user?.nomorIdentitas ?? '-',
                  jabatan: user?.jabatanLabel ?? '-',
                ),

                const SizedBox(height: AppTheme.spaceLg),

                // ---- Ringkasan status ------------------------------------
                SectionHeader(
                  title: 'Ringkasan pengajuan',
                  subtitle: 'Status seluruh pengajuan Anda',
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Menunggu',
                        value: '${ringkasan[BookingStatus.menunggu] ?? 0}',
                        icon: BookingStatus.menunggu.icon,
                        color: BookingStatus.menunggu.foreground,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm + 2),
                    Expanded(
                      child: StatCard(
                        label: 'Disetujui',
                        value: '${ringkasan[BookingStatus.disetujui] ?? 0}',
                        icon: BookingStatus.disetujui.icon,
                        color: BookingStatus.disetujui.foreground,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm + 2),
                    Expanded(
                      child: StatCard(
                        label: 'Ditolak',
                        value: '${ringkasan[BookingStatus.ditolak] ?? 0}',
                        icon: BookingStatus.ditolak.icon,
                        color: BookingStatus.ditolak.foreground,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spaceLg),

                // ---- Aksi utama ------------------------------------------
                _KartuAksi(
                  icon: Icons.add_circle_outline_rounded,
                  judul: 'Ajukan kelas pengganti',
                  keterangan: 'Pilih slot lab yang masih kosong lalu kirim',
                  warna: theme.colorScheme.primary,
                  onTap: () => _bukaFormPengajuan(context, ref),
                ),
                const SizedBox(height: AppTheme.spaceSm + 2),
                _KartuAksi(
                  icon: Icons.calendar_month_rounded,
                  judul: 'Cek ketersediaan laboratorium',
                  keterangan:
                      'Lihat slot kosong hari ini dan beberapa hari ke depan',
                  warna: theme.colorScheme.secondary,
                  onTap: () => context.go(Routes.calendar),
                ),

                const SizedBox(height: AppTheme.spaceLg),

                // ---- Jadwal terdekat -------------------------------------
                if (jadwalTerdekat.isNotEmpty) ...[
                  SectionHeader(
                    icon: Icons.upcoming_outlined,
                    title: 'Jadwal terdekat',
                    subtitle: 'Kelas pengganti yang sudah disetujui',
                    trailingLabel: 'Lihat semua',
                    onTrailingTap: () => context.go(Routes.myBookings),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  BookingCard(
                    booking: jadwalTerdekat.first,
                    namaLab: namaLab[jadwalTerdekat.first.idLab],
                    onTap: () => _bukaDetail(
                      context,
                      ref,
                      jadwalTerdekat.first,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                ],

                // ---- Pengajuan terakhir ----------------------------------
                SectionHeader(
                  icon: Icons.history_rounded,
                  title: 'Pengajuan terakhir',
                  trailingLabel: daftar.isEmpty ? null : 'Lihat semua',
                  onTrailingTap: daftar.isEmpty
                      ? null
                      : () => context.go(Routes.myBookings),
                ),
                const SizedBox(height: AppTheme.spaceMd),

                AsyncValueView(
                  value: pengajuanAsync,
                  compact: true,
                  onRetry: () => ref.invalidate(pengajuanSayaProvider),
                  builder: (data) {
                    if (data.isEmpty) {
                      return const EmptyState(
                        icon: Icons.event_busy_outlined,
                        title: 'Belum ada pengajuan',
                        message:
                            'Pengajuan kelas pengganti yang Anda buat akan '
                            'muncul di sini beserta status verifikasinya.',
                      );
                    }
                    return Column(
                      children: [
                        for (final booking in data.take(3))
                          BookingCard(
                            booking: booking,
                            namaLab: namaLab[booking.idLab],
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

class _KartuIdentitas extends StatelessWidget {
  const _KartuIdentitas({
    required this.nama,
    required this.nomorIdentitas,
    required this.jabatan,
  });

  final String nama;
  final String nomorIdentitas;
  final String jabatan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inisial = nama
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm + 2),
            ),
            child: Text(
              inisial.isEmpty ? '?' : inisial,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$nomorIdentitas · $jabatan',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuAksi extends StatelessWidget {
  const _KartuAksi({
    required this.icon,
    required this.judul,
    required this.keterangan,
    required this.warna,
    required this.onTap,
  });

  final IconData icon;
  final String judul;
  final String keterangan;
  final Color warna;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: warna.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: warna.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 26, color: warna),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    judul,
                    style: theme.textTheme.titleSmall?.copyWith(color: warna),
                  ),
                  const SizedBox(height: 2),
                  Text(keterangan, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: warna),
          ],
        ),
      ),
    );
  }
}
