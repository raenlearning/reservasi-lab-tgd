import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_exception.dart';
import '../theme/app_theme.dart';
import 'app_buttons.dart';

/// Tampilan saat data kosong, disertai ajakan tindakan bila perlu.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceLg,
          vertical: AppTheme.spaceXl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTheme.spaceLg),
              SecondaryButton(
                label: actionLabel!,
                icon: actionIcon,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tampilan kesalahan yang ramah pengguna.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  String get _message {
    if (error is AppException) return (error as AppException).userMessage;
    return AppException.from(error).userMessage;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppTheme.spaceMd : AppTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: compact ? 32 : 44,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              'Gagal memuat data',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spaceLg),
              SecondaryButton(
                label: 'Coba lagi',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Menyatukan penanganan `AsyncValue` menjadi loading / error / data.
///
/// Menghindari pengulangan `.when(...)` di setiap halaman.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.loadingLabel,
    this.compact = false,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final String? loadingLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => Center(
        child: Padding(
          padding: EdgeInsets.all(
            compact ? AppTheme.spaceMd : AppTheme.spaceXl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (loadingLabel != null) ...[
                const SizedBox(height: AppTheme.spaceMd),
                Text(
                  loadingLabel!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
      error: (error, _) => ErrorStateView(
        error: error,
        onRetry: onRetry,
        compact: compact,
      ),
    );
  }
}

/// Pita informasi (info / peringatan / sukses / bahaya).
enum InfoBannerTone { info, success, warning, danger }

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = InfoBannerTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final InfoBannerTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  ({Color foreground, Color background, IconData icon}) _styleFor(
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    switch (tone) {
      case InfoBannerTone.info:
        return (
          foreground: theme.colorScheme.primary,
          background: theme.colorScheme.primary.withValues(alpha: 0.08),
          icon: Icons.info_outline_rounded,
        );
      case InfoBannerTone.success:
        return (
          foreground: const Color(0xFF14653C),
          background: const Color(0xFFE2F5EA),
          icon: Icons.check_circle_outline_rounded,
        );
      case InfoBannerTone.warning:
        return (
          foreground: const Color(0xFF8A5300),
          background: const Color(0xFFFFF3DC),
          icon: Icons.warning_amber_rounded,
        );
      case InfoBannerTone.danger:
        return (
          foreground: theme.colorScheme.error,
          background: theme.colorScheme.error.withValues(alpha: 0.09),
          icon: Icons.error_outline_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _styleFor(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? style.icon, size: 20, color: style.foreground),
          const SizedBox(width: AppTheme.spaceSm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: style.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: style.foreground,
                    height: 1.5,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppTheme.spaceSm),
                  GestureDetector(
                    onTap: onAction,
                    child: Text(
                      actionLabel!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: style.foreground,
                        decoration: TextDecoration.underline,
                        decorationColor: style.foreground,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
