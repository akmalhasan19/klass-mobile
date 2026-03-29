import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/app_colors.dart';
import 'config/theme.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/bottom_nav.dart';
// import 'config/animations.dart'; 

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Membuat status bar transparan — konten extend di belakang status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Edge-to-edge mode (konten membentang di belakang system bars)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const KlassApp());
}

/// Root widget aplikasi Klass.
class KlassApp extends StatelessWidget {
  const KlassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Klass',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainShell(),
    );
  }
}

/// Main Shell — Container utama dengan Bottom Navigation.
/// Mengelola switching antar 3 tab utama: Home, Search, Bookmark (placeholder).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void _navigateToSettings() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, // Ensures Home is visible beneath during transition
        transitionDuration: const Duration(milliseconds: 1000),
        reverseTransitionDuration: const Duration(milliseconds: 1000),
        pageBuilder: (_, _, _) => const SettingsScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return child;
        },
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen(
          key: const ValueKey('home'),
          onSettingsTap: _navigateToSettings,
        );
      case 1:
        return const SearchScreen(key: ValueKey('search'));
      case 2:
        return const _PlaceholderScreen(
          key: ValueKey('bookmarks'),
          title: 'Bookmarks',
        );
      case 3:
        return const ProfileScreen(key: ValueKey('profile'));
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // `extendBody` agar konten bisa extend di belakang bottom nav
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 1000),
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation.drive(
              Tween<double>(begin: -1.0, end: 1.0).chain(
                CurveTween(curve: const Interval(0.0, 1.0)),
              ),
            ).drive(
              // Custom clamping logic via a Tween or manual Opacity
              CurveTween(curve: const _ClampedLinearCurve()),
            ),
            child: child,
          );
        },
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            children: [
              ...previousChildren,
              ...[currentChild].nonNulls,
            ],
          );
        },
        child: _buildCurrentPage(),
      ),
      bottomNavigationBar: Hero(
        tag: 'bottom_nav_fade',
        flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
          final isPush = flightDirection == HeroFlightDirection.push;
          final navWidget = isPush ? (fromHeroContext.widget as Hero).child : (toHeroContext.widget as Hero).child;
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Material(
                color: Colors.transparent,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Opacity(
                    opacity: (1.0 - animation.value).clamp(0.0, 1.0),
                    child: navWidget,
                  ),
                ),
              );
            },
          );
        },
        child: BottomNav(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }
}

/// Custom curve for staggering fade (2v - 1 clamped to 0..1).
class _ClampedLinearCurve extends Curve {
  const _ClampedLinearCurve();

  @override
  double transformInternal(double t) {
    return (2 * t - 1).clamp(0.0, 1.0);
  }
}

/// Placeholder screen untuk tab yang belum diimplementasi.
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.construction_rounded,
            size: 48,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming Soon',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
