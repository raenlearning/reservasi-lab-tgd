import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/lab.dart';
import '../../../data/providers/api_providers.dart';
import '../../calendar/providers/calendar_providers.dart';
import 'widgets/form_lab_sheet.dart';

/// Halaman kelola laboratorium (khusus Kepala Laboratorium).
///
/// Melengkapi kebutuhan fungsional "kalender ketersediaan lab selalu memiliki
/// data jadwal terbaru": tanpa data laboratorium, kalender tidak bisa diisi.
class AdminLabPage extends ConsumerWidget {
  const AdminLabPage({super.key});

  Future<void> _tambah(BuildContext context, WidgetRef ref) async {
    final tersimpan = await FormLabSheet.tampilkan(context);
    if (tersimpan == true) _segarkan(ref);
  }

  Future<void> _ubah(BuildContext context, WidgetRef ref, Lab lab) async {
    final tersimpan = await FormLabSheet.tampilkan(context, labAwal: lab);
    if (tersimpan == true) _segarkan(ref);
  }

  void _segarkan(WidgetRef ref) {
    ref
      ..invalidate(semuaLabProvider)
      ..invalidate(snapshotKalenderProvider)
      ..invalidate(petaKeterisianProvider);
  }

  Future<void> _hapus(BuildContext context, WidgetRef ref, Lab lab) async {
    final setuju = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus laboratorium?'),
        content: Text(
          '${lab.namaLab} akan dihapus permanen.\n\n'
          'Bila laboratorium ini masih punya jadwal atau pengajuan, sebaiknya '
          'gunakan opsi "Ubah" lalu nonaktifkan agar riwayat tetap utuh.',
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
      await ref.read(labApiProvider).hapus(lab.id);
      _segarkan(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${lab.namaLab} dihapus.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppException.from(error).userMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final labsAsync = ref.watch(semuaLabProvider);
    final labs = labsAsync.value ?? const <Lab>[];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Kelola Laboratorium', style: theme.textTheme.titleLarge),
            Text(
              '${labs.length} laboratorium terdaftar',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _tambah(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah lab'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _segarkan(ref);
          await Future<void>.delayed(const Duration(milliseconds: 300));
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: AsyncValueView<List<Lab>>(
              value: labsAsync,
              onRetry: () => ref.invalidate(semuaLabProvider),
              builder: (data) {
                if (data.isEmpty) {
                  return const EmptyState(
                    icon: Icons.meeting_room_outlined,
                    title: 'Belum ada laboratorium',
                    message:
                        'Tambahkan laboratorium terlebih dahulu agar kalender '
                        'ketersediaan dapat diisi jadwal dan diajukan reservasi.',
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    AppTheme.spaceSm,
                    20,
                    96,
                  ),
                  children: [
                    const SectionHeader(
                      icon: Icons.meeting_room_outlined,
                      title: 'Daftar laboratorium',
                      subtitle: 'Ketuk kartu untuk mengubah',
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    for (final lab in data)
                      _KartuLab(
                        lab: lab,
                        onUbah: () => _ubah(context, ref, lab),
                        onHapus: () => _hapus(context, ref, lab),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _KartuLab extends StatelessWidget {
  const _KartuLab({
    required this.lab,
    required this.onUbah,
    required this.onHapus,
  });

  final Lab lab;
  final VoidCallback onUbah;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nonaktif = !lab.isActive;

    return Opacity(
      opacity: nonaktif ? 0.6 : 1,
      child: InkWell(
        onTap: onUbah,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spaceSm + 2),
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: theme.dividerTheme.color!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  Icons.desktop_windows_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lab.namaLab,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (nonaktif)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3DC),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Nonaktif',
                              style: TextStyle(
                                color: Color(0xFF8A5300),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        lab.kapasitasLabel,
                        if (lab.lokasi != null) lab.lokasi!,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (lab.fasilitas.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        lab.fasilitas.join(' · '),
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hapus laboratorium',
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: theme.colorScheme.error,
                ),
                onPressed: onHapus,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
