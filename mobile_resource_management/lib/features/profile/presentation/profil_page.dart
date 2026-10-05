import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_providers.dart';

/// Halaman profil & pengaturan akun.
///
/// Dipakai oleh Mahasiswa/Dosen maupun Kepala Laboratorium.
class ProfilPage extends ConsumerWidget {
  const ProfilPage({super.key});

  Future<void> _konfirmasiKeluar(BuildContext context, WidgetRef ref) async {
    final setuju = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari aplikasi?'),
        content: const Text(
          'Anda perlu masuk kembali untuk mengakses kalender ketersediaan '
          'laboratorium dan pengajuan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (setuju != true) return;
    await ref.read(authControllerProvider.notifier).keluar();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final isLoading = ref.watch(
      authControllerProvider.select((state) => state.isLoading),
    );

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Profil', style: theme.textTheme.titleLarge),
            Text('Akun & pengaturan', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      body: Center(
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
              // ---- Kartu profil ----------------------------------------
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: theme.dividerTheme.color!),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 68,
                      width: 68,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        user.inisial,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    Text(
                      user.nama,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    TagBadge(
                      label: user.jabatanLabel,
                      icon: user.role.icon,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spaceLg),

              // ---- Peringatan jabatan tidak dikenali --------------------
              if (!user.jabatanDikenali) ...[
                InfoBanner(
                  tone: InfoBannerTone.warning,
                  title: 'Jabatan tidak dikenali',
                  message:
                      'Akun Anda memuat jabatan '
                      '"${user.jabatan}", yang bukan salah satu nilai '
                      'yang dikenal.\n\n'
                      'Akibatnya aplikasi memperlakukan Anda sebagai Mahasiswa, '
                      'dan server akan menolak tindakan khusus Kepala '
                      'Laboratorium. Hubungi administrator untuk memperbaiki '
                      'kolom `jabatan` pada tabel users menjadi persis: '
                      'Mahasiswa, Dosen, atau Kepala Lab.',
                ),
                const SizedBox(height: AppTheme.spaceLg),
              ],

              // ---- Data akun -------------------------------------------
              const SectionHeader(
                icon: Icons.badge_outlined,
                title: 'Data akun',
              ),
              const SizedBox(height: AppTheme.spaceMd),
              _KartuInfo(
                baris: [
                  ('NIM / NIDN', user.nomorIdentitas),
                  ('Jabatan', user.jabatan.isEmpty ? '-' : user.jabatan),
                  ('Status akun', user.isActive ? 'Aktif' : 'Nonaktif'),
                  ('ID pengguna', user.id.toString()),
                ],
              ),

              const SizedBox(height: AppTheme.spaceLg),

              PrimaryButton(
                label: 'Keluar',
                icon: Icons.logout_rounded,
                isLoading: isLoading,
                onPressed: () => _konfirmasiKeluar(context, ref),
              ),

              const SizedBox(height: AppTheme.spaceLg),
              Center(
                child: Text(
                  '${AppConfig.appName} v${AppConfig.appVersion}\n'
                  '${AppConfig.institutionName}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KartuInfo extends StatelessWidget {
  const _KartuInfo({required this.baris});

  final List<(String, String)> baris;

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
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      baris[i].$1,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      baris[i].$2,
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
