import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final initialShellState = await _loadInitialShellState();

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

  runApp(
    KlassApp(
      initialRole: initialShellState.role,
      initialIsGuest: initialShellState.isGuest,
    ),
  );
}

Future<_InitialShellState> _loadInitialShellState() async {
  final prefs = await SharedPreferences.getInstance();
  final hasAuthToken = prefs.getString('auth_token') != null;
  final cachedRole = await AuthService().getUserRole();

  return _InitialShellState(
    role: hasAuthToken ? AuthService.resolveAppRole(cachedRole) : 'teacher',
    isGuest: !hasAuthToken,
  );
}

class _InitialShellState {
  const _InitialShellState({
    required this.role,
    required this.isGuest,
  });

  final String role;
  final bool isGuest;
}

/// Root widget aplikasi Klass.
class KlassApp extends StatelessWidget {
  const KlassApp({
    super.key,
    this.initialRole = 'teacher',
    this.initialIsGuest = false,
  });

  static final GlobalKey<MainShellState> mainShellKey = GlobalKey<MainShellState>();
  final String initialRole;
  final bool initialIsGuest;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Klass',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: MainShell(
        key: mainShellKey,
        initialRole: initialRole,
        initialIsGuest: initialIsGuest,
      ),
    );
  }
}


/// Main Shell — Container utama dengan Bottom Navigation.
/// Role-aware: menampilkan tab yang berbeda untuk Teacher dan Freelancer.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.initialRole = 'teacher',
    this.initialIsGuest = false,
  });

  final String initialRole;
  final bool initialIsGuest;

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;
  bool _shouldFocusHomePrompt = false;
  late String _userRole;
  late bool _isGuest;

  @override
  void initState() {
    super.initState();
    _userRole = widget.initialRole;
    _isGuest = widget.initialIsGuest;
    _loadUserRole();
  }

  /// Load user role from cached SharedPreferences data.
  Future<void> _loadUserRole() async {
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      final role = await _authService.getUserRole();
      if (!mounted) {
        return;
      }

      setState(() {
        _isGuest = !isLoggedIn;
        _userRole = isLoggedIn ? AuthService.resolveAppRole(role) : 'teacher';
      });
    } catch (_) {
      // Silently default to teacher
      if (mounted) {
        setState(() {
          _userRole = 'teacher';
          _isGuest = true;
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

  Duration get _pageTransitionDuration {
    if (_isGuest && _currentIndex == 3) {
      return Duration.zero;
    }

    return const Duration(milliseconds: 1000);
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
        return ProfileScreen(
          key: ValueKey('profile_${_userRole}_${_isGuest ? 'guest' : 'member'}'),
          role: _userRole,
          isGuest: _isGuest,
        );
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
        return ProfileScreen(
          key: ValueKey('profile_${_userRole}_${_isGuest ? 'guest' : 'member'}'),
          role: _userRole,
          isGuest: _isGuest,
        );
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
        duration: _pageTransitionDuration,
        reverseDuration: _pageTransitionDuration,
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
        transitionBuilder: (child, animation) {
          if (_pageTransitionDuration == Duration.zero) {
            return child;
          }

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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 600), // Increased to make staggering noticeable
          switchInCurve: Curves.linear,
          switchOutCurve: Curves.linear,
          transitionBuilder: (child, animation) {
            return StaggeredFadeTransition(
              animation: animation,
              child: child,
            );
          },
          child: BottomNav(
            key: ValueKey(_userRole),
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            role: _userRole,
          ),
        ),
      ),
    );
  }
}
