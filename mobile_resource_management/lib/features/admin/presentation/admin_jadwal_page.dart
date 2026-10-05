import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/lab_schedule.dart';
import '../../../data/models/occupancy.dart';
import '../../../data/providers/api_providers.dart';
import '../../calendar/providers/calendar_providers.dart';
import 'widgets/form_jadwal_sheet.dart';

/// Prefiks id slot yang berasal dari jadwal acuan (lihat `OccupancySlot`).
const String _prefiksJadwal = 'schedule:';

/// Halaman "Input / Upload Jadwal Lab" untuk Kepala Laboratorium.
///
/// Jadwal yang diinput di sini menjadi data acuan kalender ketersediaan
/// (kebutuhan fungsional #3 pada dokumen tugas).
class AdminJadwalPage extends ConsumerStatefulWidget {
  const AdminJadwalPage({super.key});

  @override
  ConsumerState<AdminJadwalPage> createState() => _AdminJadwalPageState();
}

class _AdminJadwalPageState extends ConsumerState<AdminJadwalPage> {
  late DateTime _tanggal = DateTimeUtils.today;

  String get _tanggalKey => DateTimeUtils.toDateKey(_tanggal);

  void _geserHari(int delta) {
    setState(() => _tanggal = _tanggal.add(Duration(days: delta)));
  }

  Future<void> _pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2024),
      lastDate: DateTimeUtils.today.add(const Duration(days: 730)),
      helpText: 'Pilih tanggal jadwal',
    );
    if (hasil != null) setState(() => _tanggal = hasil);
  }

  /// Menyegarkan timeline harian dan kalender ketersediaan.
  ///
  /// Kalender ikut disegarkan karena jadwal acuan menentukan slot mana yang
  /// masih bisa diajukan.
  void _segarkan() {
    ref
      ..invalidate(jadwalHarianProvider(_tanggalKey))
      ..invalidate(pengajuanHarianProvider(_tanggalKey))
      ..invalidate(snapshotKalenderProvider);
  }

  Future<void> _tambah() async {
    final tersimpan = await FormJadwalSheet.tampilkan(context);
    if (tersimpan == true && mounted) {
      _segarkan();
      _pesanSukses('Jadwal berhasil disimpan.');
    }
  }

  Future<void> _ubah(LabSchedule jadwal) async {
    final tersimpan = await FormJadwalSheet.tampilkan(
      context,
      jadwalAwal: jadwal,
    );
    if (tersimpan == true && mounted) {
      _segarkan();
      _pesanSukses('Jadwal berhasil diperbarui.');
    }
  }

  Future<void> _hapus(LabSchedule jadwal) async {
    final setuju = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus jadwal?'),
        content: Text(
          'Jadwal ${jadwal.mataKuliah} pada '
          '${DateTimeUtils.formatTanggalPanjang(jadwal.tanggalDateTime)} '
          '${jadwal.rentangJam} akan dihapus. Slot tersebut kembali tersedia '
          'untuk pengajuan kelas pengganti.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (setuju != true) return;

    try {
      await ref.read(jadwalApiProvider).hapus(jadwal.id);
      if (!mounted) return;
      _segarkan();
      _pesanSukses('Jadwal dihapus.');
    } catch (error) {
      if (!mounted) return;
      _pesanError(AppException.from(error).userMessage);
    }
  }

  void _pesanSukses(String pesan) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }

  void _pesanError(String pesan) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(pesan),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
  }

  /// Mencari jadwal acuan asal sebuah slot (bila slot berasal dari jadwal).
  LabSchedule? _jadwalAsal(List<LabSchedule> daftar, OccupancySlot slot) {
    if (!slot.id.startsWith(_prefiksJadwal)) return null;
    final id = slot.id.substring(_prefiksJadwal.length);
    for (final jadwal in daftar) {
      // `slot.id` berbentuk `schedule:<id>` sehingga perlu dibandingkan
      // sebagai teks — `LabSchedule.id` sendiri bertipe `int`.
      if (jadwal.id.toString() == id) return jadwal;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Filter khusus halaman ini — tidak lagi berbagi state dengan halaman
    // Kalender mahasiswa (lihat [filterLabJadwalProvider]).
    final idLabFilter = ref.watch(filterLabJadwalProvider);
    final labs = ref.watch(daftarLabProvider);
    final timelineAsync = ref.watch(timelineHarianProvider(_tanggalKey));
    final jadwalHariIni =
        ref.watch(jadwalHarianProvider(_tanggalKey)).value ??
        const <LabSchedule>[];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Jadwal Lab', style: theme.textTheme.titleLarge),
            Text(
              'Input jadwal acuan laboratorium',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambah,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah jadwal'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              // ---- Pemilih tanggal --------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, AppTheme.spaceSm, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Hari sebelumnya',
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => _geserHari(-1),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: _pilihTanggal,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSm + 2,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceMd,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm + 2,
                            ),
                            border: Border.all(
                              color: theme.dividerTheme.color!,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_outlined,
                                size: 17,
                                color: theme.iconTheme.color,
                              ),
                              const SizedBox(width: AppTheme.spaceSm),
                              Flexible(
                                child: Text(
                                  DateTimeUtils.formatTanggalPanjang(_tanggal),
                                  style: theme.textTheme.titleSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hari berikutnya',
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => _geserHari(1),
                    ),
                  ],
                ),
              ),

              // ---- Filter laboratorium ----------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, AppTheme.spaceSm, 20, 0),
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'Semua lab',
                        selected: idLabFilter == null,
                        onTap: () => ref
                            .read(filterLabJadwalProvider.notifier)
                            .pilih(null),
                      ),
                      for (final lab in labs) ...[
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: lab.namaLab,
                          selected: idLabFilter == lab.id,
                          onTap: () => ref
                              .read(filterLabJadwalProvider.notifier)
                              .pilih(lab.id),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spaceMd),

              // ---- Timeline slot ----------------------------------------
              Expanded(
                child: AsyncValueView<List<OccupancySlot>>(
                  value: timelineAsync,
                  onRetry: () {
                    ref
                      ..invalidate(jadwalHarianProvider(_tanggalKey))
                      ..invalidate(pengajuanHarianProvider(_tanggalKey));
                  },
                  builder: (slots) {
                    final tampil = idLabFilter == null
                        ? slots
                        : slots
                              .where((slot) => slot.idLab == idLabFilter)
                              .toList(growable: false);

                    if (tampil.isEmpty) {
                      final tersembunyi = slots.isNotEmpty;

                      return EmptyState(
                        icon: tersembunyi
                            ? Icons.filter_alt_off_outlined
                            : Icons.event_available_outlined,
                        title: tersembunyi
                            ? 'Tersembunyi oleh filter'
                            : 'Belum ada jadwal',
                        message: tersembunyi
                            ? 'Ada ${slots.length} slot pada tanggal ini, '
                                  'tetapi tidak ada yang cocok dengan '
                                  'laboratorium yang dipilih. Ketuk "Semua lab" '
                                  'untuk menampilkannya.'
                            : 'Seluruh slot pada tanggal ini masih kosong. '
                                  'Tekan "Tambah jadwal" untuk menginput jadwal '
                                  'laboratorium.',
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                      children: [
                        SectionHeader(
                          icon: Icons.schedule_rounded,
                          title: '${tampil.length} slot terisi',
                          subtitle:
                              'Jadwal acuan dapat diubah atau dihapus; '
                              'kelas pengganti hanya dapat dilihat',
                        ),
                        const SizedBox(height: AppTheme.spaceMd),
                        for (final slot in tampil)
                          _SlotTimeline(
                            slot: slot,
                            jadwal: _jadwalAsal(jadwalHariIni, slot),
                            onUbah: _ubah,
                            onHapus: _hapus,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Baris slot pada timeline
// -----------------------------------------------------------------------------

class _SlotTimeline extends StatelessWidget {
  const _SlotTimeline({
    required this.slot,
    required this.jadwal,
    required this.onUbah,
    required this.onHapus,
  });

  final OccupancySlot slot;

  /// Terisi hanya bila slot berasal dari jadwal acuan (bisa diubah/dihapus).
  final LabSchedule? jadwal;

  final ValueChanged<LabSchedule> onUbah;
  final ValueChanged<LabSchedule> onHapus;


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warna = slot.source.color;
    final asal = jadwal;

    final judul = slot.judul.trim().isEmpty ? slot.source.label : slot.judul;

    final keterangan = [
      if (slot.namaLab != null && slot.namaLab!.trim().isNotEmpty)
        slot.namaLab!.trim(),
      if (slot.subjudul != null && slot.subjudul!.trim().isNotEmpty)
        slot.subjudul!.trim(),
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSm + 2),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: theme.dividerTheme.color!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              // `min` supaya kolom tidak meregang mengikuti tinggi baris dan
              // menggeser teks keluar dari kartu.
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      slot.rentangJam,
                      style: theme.textTheme.labelMedium?.copyWith(
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    Icon(slot.source.icon, size: 14, color: warna),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        slot.source.label,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  judul,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (keterangan.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    keterangan,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (asal != null) ...[
            IconButton(
              tooltip: 'Ubah jadwal',
              icon: const Icon(Icons.edit_outlined, size: 19),
              onPressed: () => onUbah(asal),
            ),
            IconButton(
              tooltip: 'Hapus jadwal',
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 19,
              ),
              onPressed: () => onHapus(asal),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(
                right: AppTheme.spaceSm,
                top: AppTheme.spaceXs,
              ),
              child: Text('Read-only', style: theme.textTheme.labelSmall),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Chip filter laboratorium
// -----------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
