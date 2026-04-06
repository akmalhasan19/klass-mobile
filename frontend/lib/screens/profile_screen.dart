import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:klass_app/l10n/generated/app_localizations.dart';
import 'dart:ui';
import '../config/app_colors.dart';

import 'account_settings_screen.dart';
import 'help_screen.dart';
import '../widgets/feature_coming_soon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../utils/auth_guard.dart';
import '../main.dart';

class ProfileScreen extends StatefulWidget {
  final String role;
  final bool isGuest;

  const ProfileScreen({
    super.key,
    this.role = 'teacher',
    this.isGuest = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  Map<String, dynamic>? _user;
  late bool _isLoading;
  late final ScrollController _scrollController;

  AppLocalizations _localizations() {
    return AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _isLoading = !widget.isGuest;

    if (widget.isGuest) {
      return;
    }

    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAuthToken = prefs.getString('auth_token') != null;
    final userStr = prefs.getString('user_data');

    if (userStr != null) {
      setState(() {
        _user = jsonDecode(userStr);
        _isLoading = false;
      });
    }

    if (!hasAuthToken) {
      if (!mounted) {
        return;
      }

      setState(() {
        _user = null;
        _isLoading = false;
      });
      return;
    }

    // Fetch latest from API
    final me = await _authService.getMe();
    if (me != null && mounted) {
      setState(() {
        _user = me;
        _isLoading = false;
      });
    } else if (_user == null && mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleLogout() async {
    // 1. Clear local state immediately so UI shows guest
    setState(() {
      _user = null;
      _isLoading = false;
    });

    // 2. Clear server session + all persisted data (tokens, cache, etc.)
    await _authService.logout();

    if (!mounted) return;

    // 3. Reset MainShell to guest/teacher mode and navigate to Home tab
    await KlassApp.mainShellKey.currentState?.reloadRole();
  }

  double _currentScrollOffset() {
    final positions = _scrollController.positions.toList(growable: false);
    if (positions.isEmpty) {
      return 0.0;
    }

    return positions.last.pixels;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGuest || (_user == null && !_isLoading)) {
      return _buildGuestView();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Stack(
        children: [
          // Layer 2 background
          Positioned.fill(
            child: Hero(
              tag: 'layer2_bg',
              child: Container(color: AppColors.surface),
            ),
          ),

          // Content
          Positioned.fill(
            child: Hero(
              tag: 'content_fade',
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildAppBar(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildProfileHeader(),
                          if (_user != null) ...[
                            const SizedBox(height: 24),
                            _buildStatsBento(),
                            const SizedBox(height: 32),
                            if (widget.role != 'freelancer') ...[
                              _buildInstitutionalTools(),
                              const SizedBox(height: 8),
                              _buildTeachingMaterials(),
                            ] else ...[
                              _buildFreelancerProfileSection(),
                            ],
                          ],
                          const SizedBox(height: 32),
                          _buildAccountSupport(),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestView() {
    final topPadding = MediaQuery.of(context).padding.top;
    final String titleText = _getAppBarTitle();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Stack(
          children: [
            // Layer 1: Content (Full height, starting from top)
            Positioned.fill(
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Removed _buildAppBar() sliver to allow content to start higher under the app bar area
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, topPadding + 16.0, 24, 32),
                      child: Column(
                        children: [
                          _buildGuestHero(),
                          const SizedBox(height: 32),
                          _buildGuestBentoGrid(),
                          const SizedBox(height: 32),
                          _buildGuestAuthPrompt(),
                          const SizedBox(height: 64),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Opacity(
                              opacity: 0.4,
                              child: Text(
                                _localizations().profileQuote,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Mona_Sans',
                                  fontSize: 18,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.primary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Layer 2: Overlay Top Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topPadding + 56.0,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _scrollController,
                  builder: (context, child) {
                    final offset = _currentScrollOffset();
                    final headerOpacity = (offset / 80).clamp(0.0, 1.0);
                    return _buildAppBarOverlayContent(headerOpacity, titleText);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final String titleText = _getAppBarTitle();

    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      flexibleSpace: AnimatedBuilder(
        animation: _scrollController,
        builder: (context, child) {
          final offset = _currentScrollOffset();
          final headerOpacity = (offset / 80).clamp(0.0, 1.0);
          return _buildAppBarOverlayContent(headerOpacity, titleText);
        },
      ),
    );
  }

  String _getAppBarTitle() {
    final localizations = _localizations();

    if (widget.isGuest || (_user == null && !_isLoading)) {
      return localizations.commonGuestUser;
    } else if (widget.role == 'freelancer') {
      return localizations.commonFreelancer;
    } else {
      return localizations.commonTeacher;
    }
  }

  Widget _buildAppBarOverlayContent(double headerOpacity, String titleText) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: headerOpacity * 10,
          sigmaY: headerOpacity * 10,
        ),
        child: Container(
          color: AppColors.background.withValues(
            alpha: headerOpacity * 0.9,
          ),
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.only(bottom: 12, left: 24.0),
          child: Opacity(
            opacity: headerOpacity,
            child: Text(
              titleText,
              style: const TextStyle(
                fontFamily: 'Mona_Sans',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestHero() {
    final localizations = _localizations();

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 64,
                color: AppColors.textMuted,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                localizations.commonGuestBadge,
                style: TextStyle(
                  fontFamily: 'Mona_Sans',
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          localizations.commonGuestUser,
          style: TextStyle(
            fontFamily: 'Mona_Sans',
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          localizations.profileGuestSubtitle,
          style: TextStyle(
            fontFamily: 'Mona_Sans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildGuestBentoGrid() {
    final localizations = _localizations();

    return Column(
      children: [
        // Join as Teacher Card
        _buildGuestActionCard(
          title: localizations.profileJoinTeacherTitle,
          subtitle: localizations.profileJoinTeacherSubtitle,
          label: localizations.profileJoinTeacherLabel,
          icon: Icons.school_rounded,
          isPrimary: true,
          onTap: () {
            FeatureComingSoon.show(
              context,
              title: localizations.profileTeacherRegistrationTitle,
              description: localizations.profileTeacherRegistrationDescription,
              featureName: localizations.profileTeacherRegistrationFeatureName,
              featureDescription: localizations.profileTeacherRegistrationFeatureDescription,
              icon: Icons.school_rounded,
              previewIcon: Icons.rocket_launch_rounded,
            );
          },
        ),
        const SizedBox(height: 20),
        // Join as Freelancer Card
        _buildGuestActionCard(
          title: localizations.profileJoinFreelancerTitle,
          subtitle: localizations.profileJoinFreelancerSubtitle,
          label: localizations.profileJoinFreelancerLabel,
          icon: Icons.work_rounded,
          isPrimary: false,
          onTap: () {
            FeatureComingSoon.show(
              context,
              title: localizations.profileFreelancerPortalTitle,
              description: localizations.profileFreelancerPortalDescription,
              featureName: localizations.profileFreelancerPortalFeatureName,
              featureDescription: localizations.profileFreelancerPortalFeatureDescription,
              icon: Icons.work_rounded,
              previewIcon: Icons.bolt_rounded,
            );
          },
        ),
      ],
    );
  }

  Widget _buildGuestActionCard({
    required String title,
    required String subtitle,
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final localizations = _localizations();

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 180),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: !isPrimary ? Border.all(color: AppColors.border.withValues(alpha: 0.5)) : null,
        boxShadow: [
          BoxShadow(
            color: (isPrimary ? AppColors.primary : Colors.black).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Opacity(
                    opacity: isPrimary ? 0.15 : 0.05,
                    child: Icon(
                      icon,
                      size: 160,
                      color: isPrimary ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Mona_Sans',
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isPrimary ? Colors.white.withValues(alpha: 0.7) : AppColors.textMuted,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Mona_Sans',
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isPrimary ? Colors.white : AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 220,
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'Mona_Sans',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isPrimary ? Colors.white.withValues(alpha: 0.8) : AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            isPrimary
                                ? localizations.profileJoinTeacherCta
                                : localizations.profileJoinFreelancerCta,
                            style: TextStyle(
                              fontFamily: 'Mona_Sans',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isPrimary ? Colors.white : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isPrimary ? Icons.chevron_right_rounded : Icons.arrow_forward_rounded,
                            size: 18,
                            color: isPrimary ? Colors.white : AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestAuthPrompt() {
    final localizations = _localizations();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Text(
            localizations.profileReturnTitle,
            style: TextStyle(
              fontFamily: 'Mona_Sans',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            localizations.profileReturnSubtitle,
            style: TextStyle(
              fontFamily: 'Mona_Sans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
                    ),
                  ),
                  child: Text(
                    localizations.commonLogIn,
                    style: TextStyle(
                      fontFamily: 'Mona_Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: AppColors.primary.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    localizations.commonSignUp,
                    style: TextStyle(
                      fontFamily: 'Mona_Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildProfileHeader() {
    final localizations = _localizations();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: AppColors.surfaceCard, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _user != null && _user!['avatar_url'] != null
                    ? Image.network(
                        _user!['avatar_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person_rounded, size: 64, color: AppColors.textMuted),
                      )
                    : const Icon(Icons.person_rounded, size: 64, color: AppColors.textMuted),
              ),
              if (_user != null)
                Positioned(
                  bottom: -8,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          localizations.profileVerifiedBadge,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: _isLoading 
            ? const CircularProgressIndicator()
            : Text(
                _user?['name'] ?? localizations.commonGuestUser,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _user == null
                  ? AppColors.textMuted.withValues(alpha: 0.1)
                  : widget.role == 'freelancer'
                      ? const Color(0xFF53C2B4).withValues(alpha: 0.12)
                      : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _user == null
                    ? AppColors.textMuted.withValues(alpha: 0.2)
                    : widget.role == 'freelancer'
                        ? const Color(0xFF53C2B4).withValues(alpha: 0.3)
                        : AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _user == null
                      ? Icons.person_outline_rounded
                      : widget.role == 'freelancer'
                          ? Icons.work_rounded
                          : Icons.school_rounded,
                  size: 16,
                  color: _user == null
                      ? AppColors.textMuted
                      : widget.role == 'freelancer'
                          ? const Color(0xFF53C2B4)
                          : AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  _user == null
                      ? localizations.commonGuestBadge
                      : widget.role == 'freelancer'
                          ? localizations.profileRoleFreelancerBadge
                          : localizations.profileRoleTeacherBadge,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _user == null
                        ? AppColors.textMuted
                        : widget.role == 'freelancer'
                            ? const Color(0xFF53C2B4)
                            : AppColors.primary,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_user != null) ...[
          const SizedBox(height: 20),
          Center(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildInfoChip(
                  Icons.account_balance_rounded,
                  'Greenwood International School',
                ),
                _buildInfoChip(
                  Icons.history_edu_rounded,
                  localizations.profileYearsInEducation,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => FeatureComingSoon.show(
                    context,
                    title: localizations.profileClassDashboardTitle,
                    description: localizations.profileClassDashboardDescription,
                    featureName: localizations.profileClassDashboardFeatureName,
                    featureDescription: localizations.profileClassDashboardFeatureDescription,
                    icon: Icons.dashboard_customize_rounded,
                    previewIcon: Icons.insights_rounded,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    localizations.profileClassDashboardTitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBento() {
    final localizations = _localizations();

    return Row(
      children: [
        Expanded(
          child: _buildStatCard('06', localizations.profileStatsClassesTaught, subtext: localizations.profileStatsActive),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('180', localizations.profileStatsStudentCount, subtext: localizations.profileStatsEnrolled),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('24', localizations.profileStatsCurriculumHours, subtext: localizations.profileStatsHoursPerWeek),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String value,
    String label, {
    String? subtext,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 4),
                  Icon(icon, color: AppColors.primary, size: 20),
                ] else if (subtext != null) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      subtext,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
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

  Widget _buildInstitutionalTools() {
    final localizations = _localizations();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.profileInstitutionalToolsTitle,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildToolButton(
              Icons.assignment_turned_in_rounded,
              localizations.profileToolGradebookAttendance,
            ),
            _buildToolButton(
              Icons.edit_calendar_rounded,
              localizations.profileToolCurriculumPlanner,
            ),
            _buildToolButton(Icons.campaign_rounded, localizations.profileToolSchoolAnnouncements),
            _buildToolButton(Icons.groups_rounded, localizations.profileToolParentPortal),
          ],
        ),
      ],
    );
  }

  Widget _buildToolButton(IconData icon, String label) {
    final localizations = _localizations();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => FeatureComingSoon.show(
            context,
            title: label.replaceAll('\n', ' '),
            description: localizations.profileInstitutionalToolDescription(label.replaceAll('\n', ' ')),
            featureName: localizations.profileInstitutionalSyncFeatureName,
            featureDescription: localizations.profileInstitutionalSyncFeatureDescription,
            icon: icon,
            previewIcon: Icons.sync_rounded,
          ),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeachingMaterials() {
    final localizations = _localizations();
    final profileModules = _localizedProfileModules(localizations);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.profileTeachingMaterialsTitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    localizations.profileTeachingMaterialsSubtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(localizations.commonViewAll),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...profileModules.map((module) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildModuleCard(
                title: module['title'] as String,
                description: module['description'] as String,
                imageUrl: module['imageUrl'] as String,
                status: module['status'] as String,
                isDraft: module['isDraft'] as bool,
                statsText: module['statsText'] as String,
                statsIcon: module['statsIcon'] as IconData,
              ),
            )),
      ],
    );
  }


  Widget _buildModuleCard({
    required String title,
    required String description,
    required String imageUrl,
    required String status,
    required bool isDraft,
    required String statsText,
    required IconData statsIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  color: AppColors.surfaceLight,
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    colorBlendMode: isDraft ? BlendMode.saturation : null,
                    color: isDraft ? Colors.black.withValues(alpha: 0.5) : null,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Icon(
                        Icons.image_not_supported_rounded,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDraft ? AppColors.surfaceLight : AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isDraft ? AppColors.textSecondary : Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(statsIcon, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          statsText,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSupport() {
    final localizations = _localizations();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.profileAccountSupportTitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildAccountSupportItem(
            actionKey: 'account_settings',
            icon: Icons.settings_rounded,
            label: localizations.profileAccountSettings,
            isError: false,
          ),
          const SizedBox(height: 12),
          _buildAccountSupportItem(
            actionKey: 'help_center',
            icon: Icons.help_rounded,
            label: localizations.profileHelpCenter,
            isError: false,
          ),
          const SizedBox(height: 12),
          _buildAccountSupportItem(
            actionKey: 'register_freelancer',
            icon: Icons.work_outline_rounded,
            label: localizations.profileRegisterFreelancer,
            isError: false,
          ),
          const SizedBox(height: 12),
          if (_user != null)
            _buildAccountSupportItem(
              actionKey: 'logout',
              icon: Icons.logout_rounded,
              label: localizations.profileLogout,
              isError: true,
            )
          else
            _buildAccountSupportItem(
              actionKey: 'login',
              icon: Icons.login_rounded,
              label: localizations.profileLogInCreateAccount,
              isError: false,
            ),
        ],
      ),
    );
  }

  Widget _buildAccountSupportItem({
    required String actionKey,
    required IconData icon,
    required String label,
    required bool isError,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (actionKey == 'account_settings') {
            if (await requireAuth(context)) {
              if (mounted) {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (context) => const AccountSettingsScreen(),
                      ),
                    )
                    .then((_) {
                      if (mounted) {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutQuart,
                        );
                      }
                    });
              }
            }
              } else if (actionKey == 'help_center') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const HelpScreen(),
              ),
            );
              } else if (actionKey == 'register_freelancer') {
            if (await requireAuth(context)) {
              if (mounted) {
                    final localizations = _localizations();
                FeatureComingSoon.show(
                  context,
                      title: localizations.profileFreelancerRegistrationTitle,
                      description: localizations.profileFreelancerRegistrationDescription,
                      featureName: localizations.profileFreelancerRegistrationFeatureName,
                      featureDescription: localizations.profileFreelancerRegistrationFeatureDescription,
                  icon: Icons.work_rounded,
                  previewIcon: Icons.rocket_launch_rounded,
                );
              }
            }
              } else if (actionKey == 'logout') {
            _handleLogout();
              } else if (actionKey == 'login') {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isError
                ? AppColors.red.withValues(alpha: 0.1)
                : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isError
                            ? AppColors.red.withValues(alpha: 0.1)
                            : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: isError ? AppColors.red : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isError ? AppColors.red : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isError)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFreelancerProfileSection() {
    final localizations = _localizations();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            const Icon(Icons.work_rounded, color: Color(0xFF53C2B4), size: 22),
            const SizedBox(width: 8),
            Text(
              localizations.profileFreelancerProfileTitle,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Skills section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizations.profileSkillsTitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  localizations.profileSkillGraphicDesign,
                  localizations.profileSkillPresentation,
                  localizations.profileSkillVideoEditing,
                  localizations.profileSkillEducationalContent,
                ]
                    .map((skill) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF53C2B4).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF53C2B4).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            skill,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF53C2B4),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.edit_rounded, color: AppColors.textMuted, size: 24),
                    const SizedBox(height: 8),
                    Text(
                      localizations.profileSkillsComingSoon,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Portfolio stats coming soon
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Icon(Icons.trending_up_rounded, color: AppColors.textMuted, size: 32),
              const SizedBox(height: 12),
              Text(
                localizations.profilePortfolioStatsTitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                localizations.profilePortfolioStatsDescription,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _localizedProfileModules(AppLocalizations localizations) {
    return [
      {
        'title': localizations.profileModuleOneTitle,
        'description': localizations.profileModuleOneDescription,
        'imageUrl': 'https://lh3.googleusercontent.com/aida-public/AB6AXuBTGKxSjUWwWvC2HvRdzg_RmvbCSLmCQH4UIU84ACn48uxwjyucMwK_wWVloZS99Ija6TT0Qr8yWPeti7JYBlEwelvNYlUTZ_rv5tQTZ7JqQ6H3oNIAjgCk0zGA_mjuh7FMYP92E5O8iA1zAiciFWoMTuFEqFxvhiNq5-i5tpKHdoI03HZphV9FcfsUUrzuu6vLitJfPtQVkvJ9Jxmcfzz8dyBwk2dJylV8Scjv6d22YZpLbpnRh1EQjmki4XCJ5iaz61XHKpHUxusQ',
        'status': localizations.commonPublished,
        'isDraft': false,
        'statsText': localizations.profileModuleOneStats,
        'statsIcon': Icons.group_rounded,
      },
      {
        'title': localizations.profileModuleTwoTitle,
        'description': localizations.profileModuleTwoDescription,
        'imageUrl': 'https://lh3.googleusercontent.com/aida-public/AB6AXuAE7PoZ9LTIoG5uutNqz6Xt6gD2YUvbqq305GgIp-hfioQTmG3nGy3Oueh2HGA6A0lCtP1lUmn17dyLJ2gaphosdX3DwcPgBMk8-EhDHoMWq3WmL5pVaYXw_ohoMasfJV49PFhNeIJ1Tn7i1lyKuPxvoofnIF63eoOciRZ7wDUKCpxezigtDmQajbBiTf0jU1Xi1hIUeXxYJphhgn96vCQIJencrKhiN9HuG1j5gprRDmnP4ETdGnst1cXyPh1pVICDPNqoGZHywo7g',
        'status': localizations.commonPublished,
        'isDraft': false,
        'statsText': localizations.profileModuleTwoStats,
        'statsIcon': Icons.group_rounded,
      },
      {
        'title': localizations.profileModuleThreeTitle,
        'description': localizations.profileModuleThreeDescription,
        'imageUrl': 'https://lh3.googleusercontent.com/aida-public/AB6AXuCR6hR6bvffsyKtu12OhoJs6jMLIN6XlZ7V_c10UhZ4NnbX-CVQzaD48EjnPlC_ZG76rC7T7d82o5F7bBRsNmeezOeU7-Rmtkn_BXIU88LmGYkaduQGJhsEZHbEYkvc0x_Jpll2b4-3oBvv0b0V711JUu--D242lHRWTM0pPN6dZVKx8kON4x5QfsP4d_kRrzv0gyf6WyyKFkKbkjcHPqQq3PUtcf3K1lrg-j-6jPoH3dZo_H62th4HDgoOU9K8Jzv-2LMxpn0Lcwnj',
        'status': localizations.commonDraft,
        'isDraft': true,
        'statsText': localizations.profileModuleThreeStats,
        'statsIcon': Icons.history_edu_rounded,
      },
    ];
  }
}
