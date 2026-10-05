import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_text_field.dart';
import '../providers/auth_providers.dart';

/// Halaman masuk memakai NIM / NIDN.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomorIdentitasController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nomorIdentitasController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final pesan = await ref
        .read(authControllerProvider.notifier)
        .masuk(
          nomorIdentitas: _nomorIdentitasController.text,
          password: _passwordController.text,
        );

    if (pesan != null && mounted) _tampilkanError(pesan);
  }

  void _tampilkanError(String pesan) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(pesan),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
  }

  /// Belum ada endpoint pengaturan ulang kata sandi di backend.
  ///
  /// Karena itu layar ini hanya memberi arahan manual — bukan memanggil API
  /// yang tidak ada, yang akan selalu berakhir dengan galat.
  Future<void> _lupaKataSandi() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lupa kata sandi'),
        content: const Text(
          'Pengaturan ulang kata sandi belum tersedia di aplikasi.\n\n'
          'Silakan hubungi Kepala Laboratorium atau administrator untuk '
          'mengatur ulang kata sandi akun Anda.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Mengerti'),
          ),
        ],
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: AppTheme.spaceXl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _Header(theme: theme),
                    const SizedBox(height: AppTheme.spaceXl),
                    AppTextField(
                      label: 'NIRM / NIDN',
                      hint: 'Masukkan NIRM anda',
                      controller: _nomorIdentitasController,
                      validator: Validators.nomorIdentitas,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.badge_outlined,
                      enabled: !isLoading,
                      autofocus: true,
                      autofillHints: const [AutofillHints.username],
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    AppTextField(
                      label: 'Kata sandi',
                      hint: 'Minimal ${AppConfig.minPasswordLength} karakter',
                      controller: _passwordController,
                      validator: (value) =>
                          (value ?? '').isEmpty ? 'Kata sandi wajib diisi.' : null,
                      obscureText: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      enabled: !isLoading,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      autofillHints: const [AutofillHints.password],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isLoading ? null : _lupaKataSandi,
                        child: const Text('Lupa kata sandi?'),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    PrimaryButton(
                      label: 'Masuk',
                      icon: Icons.login_rounded,
                      isLoading: isLoading,
                      onPressed: _submit,
                    ),

                    const SizedBox(height: AppTheme.spaceMd),
                    SecondaryButton(
                      label: 'Daftar akun baru',
                      icon: Icons.person_add_alt_1_outlined,
                      onPressed: isLoading
                          ? null
                          : () {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .bersihkanError();
                              context.go(Routes.register);
                            },
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

class _Header extends StatelessWidget {
  const _Header({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 200,
          child: Image.asset(
            'assets/image/triguna-dharma.png',
          ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        Text(
          AppConfig.appName,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppTheme.spaceXs),
        Text(
          '${AppConfig.institutionName} · ${AppConfig.appTagline}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
