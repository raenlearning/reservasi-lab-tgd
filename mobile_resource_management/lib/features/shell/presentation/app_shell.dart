import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// Satu tab pada navigasi bawah.
class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Kerangka aplikasi dengan navigasi bawah.
///
/// Memakai [StatefulNavigationShell] sehingga setiap tab mempertahankan
/// posisi scroll dan state-nya masing-masing — penting agar pengguna tidak
/// kehilangan konteks saat berpindah antara kalender dan daftar pengajuan.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.destinations,
  });

  final StatefulNavigationShell navigationShell;
  final List<AppDestination> destinations;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      // Menekan tab yang sedang aktif akan mengembalikan ke akar tab tersebut.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.dividerTheme.color ?? Colors.black12),
          ),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(
                  destination.selectedIcon,
                  color: theme.colorScheme.primary,
                ),
                label: destination.label,
                tooltip: destination.label,
              ),
          ],
        ),
      ),
    );
  }
}

/// Pembungkus konten tab dengan padding dan batas lebar agar tetap nyaman
/// dibaca di tablet.
class ShellPageScaffold extends StatelessWidget {
  const ShellPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.subtitle,
    this.floatingActionButton,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            if (subtitle != null)
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: actions,
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: AppTheme.pagePadding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
