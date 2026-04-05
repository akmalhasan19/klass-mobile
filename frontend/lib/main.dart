import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/theme.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/bookmark_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/freelancer_jobs_screen.dart';
import 'screens/freelancer_portfolio_screen.dart';
import 'screens/freelancer_home_screen.dart';
import 'services/auth_service.dart';
import 'widgets/bottom_nav.dart';
import 'config/animations.dart'; 

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

  static final GlobalKey<MainShellState> mainShellKey = GlobalKey<MainShellState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Klass',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: MainShell(key: mainShellKey),
    );
  }
}


/// Main Shell — Container utama dengan Bottom Navigation.
/// Role-aware: menampilkan tab yang berbeda untuk Teacher dan Freelancer.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;
  bool _shouldFocusHomePrompt = false;
  String _userRole = 'teacher'; // Default role

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  /// Load user role from cached SharedPreferences data.
  Future<void> _loadUserRole() async {
    try {
      final role = await _authService.getUserRole();
      if (!mounted) {
        return;
      }

      setState(() {
        _userRole = AuthService.resolveAppRole(role);
      });
    } catch (_) {
      // Silently default to teacher
      if (mounted) {
        setState(() {
          _userRole = 'teacher';
        });
      }
    }
  }

  /// Reload role from SharedPreferences (called after login/registration).
  Future<void> reloadRole() async {
    await _loadUserRole();
    setState(() {
      _currentIndex = 0; // Reset to first tab
    });
  }

  void setTabIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _handleNavigateToHome([bool focusPrompt = false]) {
    setState(() {
      _currentIndex = 0;
      _shouldFocusHomePrompt = focusPrompt;
    });
  }

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

  void _navigateToGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const GalleryScreen()),
    );
  }

  Widget _buildCurrentPage() {
    if (_userRole == 'freelancer') {
      return _buildFreelancerPage();
    }
    return _buildTeacherPage();
  }

  /// Teacher tabs: Home, Search, Workspace, Profile
  Widget _buildTeacherPage() {
    switch (_currentIndex) {
      case 0:
        final home = HomeScreen(
          key: const ValueKey('home'),
          onSettingsTap: _navigateToSettings,
          shouldFocusPrompt: _shouldFocusHomePrompt,
          role: _userRole,
        );
        // Reset flag after consumption
        _shouldFocusHomePrompt = false;
        return home;
      case 1:
        return const SearchScreen(key: ValueKey('search'));
      case 2:
        return BookmarkScreen(
          key: const ValueKey('bookmarks'),
          onCreateNewModule: () => _handleNavigateToHome(true),
          onViewGallery: _navigateToGallery,
        );
      case 3:
        return ProfileScreen(key: const ValueKey('profile'), role: _userRole);
      default:
        return const SizedBox.shrink();
    }
  }

  /// Freelancer tabs: Home, Jobs, Portfolio, Profile
  Widget _buildFreelancerPage() {
    switch (_currentIndex) {
      case 0:
        return FreelancerHomeScreen(
          key: const ValueKey('freelancer_home'),
          onSettingsTap: _navigateToSettings,
        );
      case 1:
        return const FreelancerJobsScreen(key: ValueKey('freelancer_jobs'));
      case 2:
        return const FreelancerPortfolioScreen(key: ValueKey('freelancer_portfolio'));
      case 3:
        return ProfileScreen(key: const ValueKey('profile'), role: _userRole);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _userRole == 'freelancer'
          ? const Color(0xFF1A1A2E)
          : Theme.of(context).scaffoldBackgroundColor,
      // `extendBody` agar konten bisa extend di belakang bottom nav
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 1000),
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
        transitionBuilder: (child, animation) {
          return StaggeredFadeTransition(
            animation: animation,
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
          role: _userRole,
        ),
      ),
    );
  }
}
