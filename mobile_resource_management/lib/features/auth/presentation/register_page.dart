import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/models/enums.dart';
import '../providers/auth_providers.dart';

/// Halaman registrasi akun Mahasiswa / Dosen.
///
/// Peran Kepala Laboratorium sengaja tidak dapat dipilih di sini — akunnya
/// dibuat oleh administrator agar tidak terjadi eskalasi hak akses.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _nomorIdentitasController = TextEditingController();
  final _passwordController = TextEditingController();
  final _konfirmasiController = TextEditingController();

  UserRole _role = UserRole.mahasiswa;

  @override
  void dispose() {
    _namaController.dispose();
    _nomorIdentitasController.dispose();
    _passwordController.dispose();
    _konfirmasiController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final pesan = await ref
        .read(authControllerProvider.notifier)
        .daftar(
          nomorIdentitas: _nomorIdentitasController.text,
          nama: _namaController.text,
          role: _role,
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (pesan == null) {
      // Router akan otomatis mengalihkan karena sesi sudah terbentuk.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Akun berhasil dibuat. Selamat datang!'),
          ),
        );
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(pesan),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(
      authControllerProvider.select((state) => state.isLoading),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar akun'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Kembali',
          onPressed: () {
            ref.read(authControllerProvider.notifier).bersihkanError();
            context.go(Routes.login);
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: AppTheme.spaceLg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Buat akun baru',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppTheme.spaceXs),
                    Text(
                      'Gunakan NIM (mahasiswa) atau NIDN (dosen) yang terdaftar '
                      'di ${AppConfig.institutionName}.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppTheme.spaceLg),

                    _RoleSelector(
                      value: _role,
                      enabled: !isLoading,
                      onChanged: (role) => setState(() => _role = role),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),

                    AppTextField(
                      label: 'Nama lengkap',
                      hint: 'Nama sesuai data akademik',
                      controller: _namaController,
                      validator: Validators.nama,
                      prefixIcon: Icons.person_outline_rounded,
                      enabled: !isLoading,
                      textCapitalization: TextCapitalization.words,
                      autofocus: true,
                      autofillHints: const [AutofillHints.name],
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    AppTextField(
                      label: _role == UserRole.mahasiswa ? 'NIM' : 'NIDN',
                      hint: _role == UserRole.mahasiswa
                          ? 'Contoh: 2021010042'
                          : 'Contoh: 0123456789',
                      controller: _nomorIdentitasController,
                      validator: Validators.nomorIdentitas,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.badge_outlined,
                      enabled: !isLoading,
                      helperText:
                          'Dipakai untuk masuk ke aplikasi. Tidak dapat diubah.',
                      autofillHints: const [AutofillHints.username],
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    AppTextField(
                      label: 'Kata sandi',
                      hint: 'Minimal ${AppConfig.minPasswordLength} karakter',
                      controller: _passwordController,
                      validator: Validators.password,
                      obscureText: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      enabled: !isLoading,
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    AppTextField(
                      label: 'Konfirmasi kata sandi',
                      hint: 'Ulangi kata sandi',
                      controller: _konfirmasiController,
                      validator: (value) => Validators.konfirmasiPassword(
                        value,
                        _passwordController.text,
                      ),
                      obscureText: true,
                      prefixIcon: Icons.lock_reset_rounded,
                      enabled: !isLoading,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),

                    PrimaryButton(
                      label: 'Daftar',
                      icon: Icons.person_add_alt_1_rounded,
                      isLoading: isLoading,
                      onPressed: _submit,
                    ),
                   
                    const SizedBox(height: AppTheme.spaceMd),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sudah punya akun?',
                          style: theme.textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  ref
                                      .read(authControllerProvider.notifier)
                                      .bersihkanError();
                                  context.go(Routes.login);
                                },
                          child: const Text('Masuk'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pemilih peran Mahasiswa / Dosen.
class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final UserRole value;
  final ValueChanged<UserRole> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Jabatan', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final role in UserRole.selfRegistrable) ...[
              Expanded(
                child: _RoleOption(
                  role: role,
                  selected: value == role,
                  enabled: enabled,
                  onTap: () => onChanged(role),
                ),
              ),
              if (role != UserRole.selfRegistrable.last)
                const SizedBox(width: AppTheme.spaceSm + 2),
            ],
          ],
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm + 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceSm + 4,
        ),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.08)
              : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm + 2),
          border: Border.all(
            color: selected ? accent : theme.dividerTheme.color!,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              role.icon,
              size: 19,
              color: selected ? accent : theme.iconTheme.color,
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Text(
                role.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: selected ? accent : null,
                  fontSize: 12
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 17, color: accent),
          ],
        ),
      ),
    );
  }
}
