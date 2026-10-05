import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/booking.dart';
import '../../booking/presentation/widgets/booking_card.dart';
import '../../booking/presentation/widgets/detail_pengajuan_sheet.dart';
import '../../booking/presentation/widgets/form_pengajuan_sheet.dart';
import '../../booking/providers/booking_providers.dart';
import '../../calendar/providers/calendar_providers.dart';

/// Daftar pengajuan milik pengguna yang sedang login.
class PengajuanSayaPage extends ConsumerStatefulWidget {
  const PengajuanSayaPage({super.key});

  @override
  ConsumerState<PengajuanSayaPage> createState() => _PengajuanSayaPageState();
}

class _PengajuanSayaPageState extends ConsumerState<PengajuanSayaPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _bukaDetail(Booking booking) async {
    final berubah = await DetailPengajuanSheet.tampilkan(context, booking);
    if (berubah == true) ref.invalidate(pengajuanSayaProvider);
  }

  Future<void> _bukaFormPengajuan() async {
    final terkirim = await FormPengajuanSheet.tampilkan(context);
    if (terkirim == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Pengajuan terkirim. Menunggu verifikasi Kepala Laboratorium.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pengajuanAsync = ref.watch(pengajuanSayaProvider);
    final namaLab = ref.watch(namaLabProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Pengajuan saya', style: theme.textTheme.titleLarge),
            Text(
              'Riwayat reservasi kelas pengganti',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Semua'),
            Tab(text: 'Menunggu'),
            Tab(text: 'Disetujui'),
            Tab(text: 'Ditolak'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _bukaFormPengajuan,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajukan'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: AsyncValueView<List<Booking>>(
            value: pengajuanAsync,
            onRetry: () => ref.invalidate(pengajuanSayaProvider),
            builder: (data) => TabBarView(
              controller: _tabController,
              children: [
                _Daftar(
                  daftar: data,
                  namaLab: namaLab,
                  kosongPesan:
                      'Pengajuan kelas pengganti yang Anda buat akan muncul '
                      'di sini beserta status verifikasinya.',
                  onPilih: _bukaDetail,
                ),
                _Daftar(
                  daftar: data
                      .where((b) => b.status.isMenunggu)
                      .toList(growable: false),
                  namaLab: namaLab,
                  kosongPesan: 'Tidak ada pengajuan yang menunggu verifikasi.',
                  onPilih: _bukaDetail,
                ),
                _Daftar(
                  daftar: data
                      .where((b) => b.status.isDisetujui)
                      .toList(growable: false),
                  namaLab: namaLab,
                  kosongPesan: 'Belum ada pengajuan yang disetujui.',
                  onPilih: _bukaDetail,
                ),
                _Daftar(
                  daftar: data
                      .where((b) => b.status.isDitolak)
                      .toList(growable: false),
                  namaLab: namaLab,
                  kosongPesan: 'Tidak ada pengajuan yang ditolak.',
                  onPilih: _bukaDetail,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Daftar extends StatelessWidget {
  const _Daftar({
    required this.daftar,
    required this.namaLab,
    required this.kosongPesan,
    required this.onPilih,
  });

  final List<Booking> daftar;
  final Map<int, String> namaLab;
  final String kosongPesan;
  final ValueChanged<Booking> onPilih;

  @override
  Widget build(BuildContext context) {
    if (daftar.isEmpty) {
      return EmptyState(
        icon: Icons.event_busy_outlined,
        title: 'Belum ada data',
        message: kosongPesan,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        AppTheme.spaceMd,
        20,
        AppTheme.spaceXl,
      ),
      children: [
        SectionHeader(
          icon: Icons.format_list_bulleted_rounded,
          title: '${daftar.length} pengajuan',
          subtitle: 'Ketuk kartu untuk melihat detail',
        ),
        const SizedBox(height: AppTheme.spaceMd),
        for (final booking in daftar)
          BookingCard(
            booking: booking,
            namaLab: namaLab[booking.idLab],
            onTap: () => onPilih(booking),
          ),
      ],
    );
  }
}
