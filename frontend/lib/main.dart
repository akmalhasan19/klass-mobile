import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/theme.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/bookmark_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/gallery_screen.dart';
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
/// Mengelola switching antar 4 tab utama: Home, Search, Workspace, Profile.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _shouldFocusHomePrompt = false;

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
    switch (_currentIndex) {
      case 0:
        final home = HomeScreen(
          key: const ValueKey('home'),
          onSettingsTap: _navigateToSettings,
          shouldFocusPrompt: _shouldFocusHomePrompt,
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
        ),
      ),
    );
  }
}
