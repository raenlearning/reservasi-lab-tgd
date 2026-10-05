import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_dasbor_page.dart';
import '../../features/admin/presentation/admin_jadwal_page.dart';
import '../../features/admin/presentation/admin_lab_page.dart';
import '../../features/admin/presentation/admin_verifikasi_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/booking/presentation/pengajuan_saya_page.dart';
import '../../features/calendar/presentation/kalender_ketersediaan_page.dart';
import '../../features/home/presentation/beranda_page.dart';
import '../../features/profile/presentation/profil_page.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../theme/app_theme.dart';
import 'routes.dart';

/// Navigasi utama aplikasi.
///
/// Guard berbasis sesi + peran:
/// * sesi belum diketahui      -> layar tunggu
/// * belum login               -> halaman masuk
/// * login tapi profil hilang  -> halaman profil belum lengkap
/// * login & profil lengkap    -> area sesuai peran (Mahasiswa/Dosen vs Kepala Lab)
///
/// `redirect` membaca status sesi langsung dari [authSessionProvider], dan
/// router di-*refresh* setiap kali status itu berubah.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AsyncValue<AuthSession>>(authSessionProvider, (_, _) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(authSessionProvider);
      final lokasi = state.matchedLocation;

      final diSplash = lokasi == Routes.splash;
      final diHalamanAuth =
          lokasi == Routes.login || lokasi == Routes.register;

      // 1. Status sesi belum diketahui -> tahan di layar tunggu.
      if (session.isLoading) {
        return diSplash ? null : Routes.splash;
      }

      // 2. Gagal membaca sesi (mis. jaringan) -> arahkan ke halaman masuk.
      if (session.hasError) {
        return diHalamanAuth ? null : Routes.login;
      }

      final nilai = session.value ?? const AuthBelumMasuk();

      switch (nilai) {
        // 3. Status sesi belum diketahui.
        case AuthMemuat():
          return diSplash ? null : Routes.splash;

        // 4. Belum login.
        case AuthBelumMasuk():
          return diHalamanAuth ? null : Routes.login;

        // 5. Login dan profil lengkap -> area sesuai peran.
        //
        // Tidak ada lagi keadaan "terautentikasi tetapi profil belum ada":
        // pada Laravel, `GET /api/me` mengembalikan profil pengguna itu sendiri,
        // sehingga keberadaan token selalu berarti profil tersedia.
        case AuthMasuk(user: final user):
          if (diSplash || diHalamanAuth) {
            return user.isAdmin ? Routes.adminDashboard : Routes.home;
          }
          final diAreaAdmin = Routes.isAdminArea(lokasi);
          if (user.isAdmin && !diAreaAdmin) return Routes.adminDashboard;
          if (!user.isAdmin && diAreaAdmin) return Routes.home;
          return null;
      }
    },
    errorBuilder: (context, state) => _HalamanTidakDitemukan(
      lokasi: state.uri.toString(),
    ),
    routes: [
      // -----------------------------------------------------------------------
      // Gerbang & autentikasi
      // -----------------------------------------------------------------------
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterPage(),
      ),

      // -----------------------------------------------------------------------
      // Area Mahasiswa / Dosen
      // -----------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          destinations: _destinasiPengguna,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const BerandaPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.calendar,
                builder: (context, state) =>
                    const KalenderKetersediaanPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.myBookings,
                builder: (context, state) => const PengajuanSayaPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfilPage(),
              ),
            ],
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // Halaman admin di luar navigasi bawah
      // -----------------------------------------------------------------------
      GoRoute(
        path: Routes.adminLab,
        builder: (context, state) => const AdminLabPage(),
      ),

      // -----------------------------------------------------------------------
      // Area Kepala Laboratorium
      // -----------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          destinations: _destinasiAdmin,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminDashboard,
                builder: (context, state) => const AdminDasborPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminSchedule,
                builder: (context, state) => const AdminJadwalPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminApproval,
                builder: (context, state) => const AdminVerifikasiPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adminProfile,
                builder: (context, state) => const ProfilPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

const List<AppDestination> _destinasiPengguna = [
  AppDestination(
    label: 'Beranda',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  AppDestination(
    label: 'Kalender',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
  ),
  AppDestination(
    label: 'Pengajuan',
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment_rounded,
  ),
  AppDestination(
    label: 'Profil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

const List<AppDestination> _destinasiAdmin = [
  AppDestination(
    label: 'Dasbor',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
  ),
  AppDestination(
    label: 'Jadwal',
    icon: Icons.event_note_outlined,
    selectedIcon: Icons.event_note_rounded,
  ),
  AppDestination(
    label: 'Verifikasi',
    icon: Icons.fact_check_outlined,
    selectedIcon: Icons.fact_check_rounded,
  ),
  AppDestination(
    label: 'Profil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

/// Halaman cadangan untuk lokasi yang tidak dikenal.
class _HalamanTidakDitemukan extends StatelessWidget {
  const _HalamanTidakDitemukan({required this.lokasi});

  final String lokasi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.explore_off_outlined,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Text(
                'Halaman tidak ditemukan',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                lokasi,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppTheme.spaceLg),
              FilledButton(
                onPressed: () => context.go(Routes.splash),
                child: const Text('Kembali ke awal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
