import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/lab.dart';
import '../../auth/providers/auth_providers.dart';
import '../../booking/presentation/widgets/form_pengajuan_sheet.dart';
import '../providers/calendar_providers.dart';
import 'widgets/lab_availability_card.dart';

/// Halaman "Cek Kalender Ketersediaan Lab".
///
/// Menampilkan keterisian seluruh laboratorium secara real-time: data berasal
/// dari jadwal yang diinput Kepala Laboratorium ditambah reservasi yang sudah
/// disetujui, dan otomatis ikut berubah ketika ada pengajuan baru.
class KalenderKetersediaanPage extends ConsumerStatefulWidget {
  const KalenderKetersediaanPage({super.key});

  @override
  ConsumerState<KalenderKetersediaanPage> createState() =>
      _KalenderKetersediaanPageState();
}

class _KalenderKetersediaanPageState
    extends ConsumerState<KalenderKetersediaanPage> {
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = ref.read(rentangKalenderProvider).bulan;
  }

  Future<void> _refresh() async {
    ref.invalidate(snapshotKalenderProvider);

    try {
      await ref.read(snapshotKalenderProvider.future);
    } catch (_) {
      // Kegagalan sudah dicatat di `statusPollingProvider` dan tampil sebagai
      // penanda kecil di layar. Kalau dibiarkan naik, RefreshIndicator akan
      // melaporkannya sebagai unhandled async error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(rentangKalenderProvider);

    // Penanda pada kalender bulanan: jumlah slot terpakai per tanggal.
    final petaKeterisian = ref.watch(petaKeterisianProvider);
    final penanda = <String, int>{
      for (final entry in petaKeterisian.entries) entry.key: entry.value.length,
    };

    final labs = ref.watch(daftarLabProvider);
    final ketersediaan = ref.watch(
      ketersediaanHariProvider(filter.tanggalEfektifKey),
    );
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Kalender Lab', style: theme.textTheme.titleLarge),
            Text(
              'Ketersediaan laboratorium real-time',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Hari ini',
            icon: const Icon(Icons.today_rounded),
            onPressed: () {
              final controller = ref.read(rentangKalenderProvider.notifier);
              controller.kembaliKeHariIni();
              setState(() => _focusedDay = DateTimeUtils.today);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceXl),
              children: [
                const SizedBox(height: AppTheme.spaceSm),

                // ---- Kalender bulanan -------------------------------------
                Padding(
                  padding: AppTheme.pagePadding,
                  child: _KartuKalender(
                    focusedDay: _focusedDay,
                    bulanLabel: filter.labelBulan,
                    penanda: penanda,
                    onBulanSebelumnya: () {
                      ref
                          .read(rentangKalenderProvider.notifier)
                          .geserBulan(-1);
                      setState(() {
                        _focusedDay = DateTimeUtils.firstDayOfMonth(
                          DateTimeUtils.geserBulan(filter.kunciBulan, -1),
                        );
                      });
                    },
                    onBulanBerikutnya: () {
                      ref.read(rentangKalenderProvider.notifier).geserBulan(1);
                      setState(() {
                        _focusedDay = DateTimeUtils.firstDayOfMonth(
                          DateTimeUtils.geserBulan(filter.kunciBulan, 1),
                        );
                      });
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      ref
                          .read(rentangKalenderProvider.notifier)
                          .pilihTanggal(selectedDay);
                      setState(() => _focusedDay = focusedDay);
                    },
                    onPageChanged: (focusedDay) {
                      ref
                          .read(rentangKalenderProvider.notifier)
                          .tampilkanBulan(focusedDay);
                      setState(() => _focusedDay = focusedDay);
                    },
                    selectedDay: filter.tanggalEfektif,
                  ),
                ),

                const SizedBox(height: AppTheme.spaceMd),

                // ---- Legenda ----------------------------------------------
                Padding(
                  padding: AppTheme.pagePadding,
                  child: const _Legenda(),
                ),

                const SizedBox(height: AppTheme.spaceMd),

                // ---- Filter laboratorium ---------------------------------
                Padding(
                  padding: AppTheme.pagePadding,
                  child: _FilterLab(
                    labs: labs,
                    idLabTerpilih: filter.labId,
                    onPilih: (idLab) => ref
                        .read(rentangKalenderProvider.notifier)
                        .pilihLab(idLab),
                  ),
                ),

                const SizedBox(height: AppTheme.spaceLg),

                // ---- Daftar ketersediaan ---------------------------------
                Padding(
                  padding: AppTheme.pagePadding,
                  child: SectionHeader(
                    icon: Icons.event_note_outlined,
                    title: DateTimeUtils.formatTanggalPanjang(
                      filter.tanggalEfektif,
                    ),
                    subtitle: filter.labId == null
                        ? 'Seluruh laboratorium'
                        : 'Difilter satu laboratorium',
                  ),
                ),

                const SizedBox(height: AppTheme.spaceMd),

                Padding(
                  padding: AppTheme.pagePadding,
                  child: ketersediaan.isEmpty
                      ? const EmptyState(
                          icon: Icons.meeting_room_outlined,
                          title: 'Belum ada data laboratorium',
                          message:
                              'Data laboratorium masih kosong. Hubungi Kepala '
                              'Laboratorium untuk menambahkan data lab terlebih '
                              'dahulu.',
                        )
                      : Column(
                          children: [
                            for (final item in ketersediaan)
                              LabAvailabilityCard(
                                availability: item,
                                // Kepala Lab tidak mengajukan reservasi, jadi
                                // tombolnya tidak ditampilkan untuk peran itu.
                                onAjukan: isAdmin
                                    ? null
                                    : () => _bukaFormPengajuan(item.idLab),
                              ),
                          ],
                        ),
                ),

                const SizedBox(height: AppTheme.spaceSm),
                const Padding(
                  padding: AppTheme.pagePadding,
                  child: InfoBanner(
                    tone: InfoBannerTone.info,
                    message:
                        'Kalender ini terbarui otomatis setiap ada pengajuan '
                        'baru atau perubahan jadwal dari Kepala Laboratorium. '
                        'Tarik ke bawah untuk menyegarkan manual.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Membuka formulir pengajuan dengan lab & tanggal yang sudah terisi.
  Future<void> _bukaFormPengajuan(int idLab) async {
    final filter = ref.read(rentangKalenderProvider);
    final terkirim = await FormPengajuanSheet.tampilkan(
      context,
      idLabAwal: idLab,
      tanggalAwal: filter.tanggalEfektif,
    );

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
}

// -----------------------------------------------------------------------------
// Kartu kalender bulanan
// -----------------------------------------------------------------------------

class _KartuKalender extends StatelessWidget {
  const _KartuKalender({
    required this.focusedDay,
    required this.bulanLabel,
    required this.penanda,
    required this.onBulanSebelumnya,
    required this.onBulanBerikutnya,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.selectedDay,
  });

  final DateTime focusedDay;
  final String bulanLabel;
  final Map<String, int> penanda;
  final VoidCallback onBulanSebelumnya;
  final VoidCallback onBulanBerikutnya;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final ValueChanged<DateTime> onPageChanged;
  final DateTime selectedDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hariIni = DateTimeUtils.today;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: theme.dividerTheme.color!),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceSm,
              AppTheme.spaceSm,
              AppTheme.spaceSm,
              0,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Bulan sebelumnya',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: onBulanSebelumnya,
                ),
                Expanded(
                  child: Text(
                    bulanLabel,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Bulan berikutnya',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: onBulanBerikutnya,
                ),
              ],
            ),
          ),
          TableCalendar<Object>(
            locale: DateTimeUtils.localeId,
            firstDay: DateTime(hariIni.year - 1, hariIni.month, 1),
            lastDay: DateTime(
              hariIni.year + 1,
              hariIni.month + AppConfig.bookingHorizonDays ~/ 30 + 1,
              0,
            ),
            focusedDay: focusedDay,
            rowHeight: 48,
            daysOfWeekHeight: 28,
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerVisible: false,
            availableGestures: AvailableGestures.horizontalSwipe,
            selectedDayPredicate: (day) =>
                DateTimeUtils.isSameDay(day, selectedDay),
            onDaySelected: onDaySelected,
            onPageChanged: onPageChanged,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
              defaultTextStyle: theme.textTheme.bodyMedium!.copyWith(
                color: theme.textTheme.bodyLarge?.color,
              ),
              weekendTextStyle: theme.textTheme.bodyMedium!.copyWith(
                color: theme.textTheme.bodyLarge?.color,
              ),
              disabledTextStyle: theme.textTheme.bodyMedium!.copyWith(
                color: AppColors.textDisabled,
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: theme.textTheme.labelSmall!.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              weekendStyle: theme.textTheme.labelSmall!.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            calendarBuilders: CalendarBuilders<Object>(
              markerBuilder: (context, day, _) {
                final jumlah = penanda[DateTimeUtils.toDateKey(day)] ?? 0;
                if (jumlah == 0) return null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < jumlah.clamp(1, 4); i++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.2),
                          height: 5,
                          width: 5,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Legenda warna
// -----------------------------------------------------------------------------

class _Legenda extends StatelessWidget {
  const _Legenda();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: AppTheme.spaceMd,
      runSpacing: AppTheme.spaceSm,
      children: [
        _item(theme, const Color(0xFF12447A), 'Jadwal reguler'),
        _item(theme, const Color(0xFF0E8C7F), 'Kelas pengganti'),
        _item(theme, const Color(0xFF6B7A8F), 'Menunggu verifikasi'),
        _item(theme, const Color(0xFF8A5300), 'Pemeliharaan'),
      ],
    );
  }

  Widget _item(ThemeData theme, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 9,
          width: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Filter laboratorium
// -----------------------------------------------------------------------------

class _FilterLab extends StatelessWidget {
  const _FilterLab({
    required this.labs,
    required this.idLabTerpilih,
    required this.onPilih,
  });

  final List<Lab> labs;
  final int? idLabTerpilih;
  final ValueChanged<int?> onPilih;

  @override
  Widget build(BuildContext context) {
    if (labs.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(
            label: 'Semua lab',
            selected: idLabTerpilih == null,
            onTap: () => onPilih(null),
          ),
          for (final lab in labs) ...[
            const SizedBox(width: 6),
            _Chip(
              label: lab.namaLab,
              selected: idLabTerpilih == lab.id,
              onTap: () => onPilih(lab.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent : theme.dividerTheme.color!,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected ? theme.colorScheme.onPrimary : null,
          ),
        ),
      ),
    );
  }
}
