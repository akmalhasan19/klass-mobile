import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  const ProfileScreen({super.key, this.role = 'teacher'});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  late final ScrollController _scrollController;

  /// Profile curriculum modules — placeholder data for the profile screen.
  /// In a future phase, this will be fetched from the API.
  static final List<Map<String, dynamic>> _profileModules = [
    {
      'title': 'Intro to Quantum Physics',
      'description': 'A comprehensive journey from classical mechanics to the mysteries of quantum entanglements.',
      'imageUrl': 'https://lh3.googleusercontent.com/aida-public/AB6AXuBTGKxSjUWwWvC2HvRdzg_RmvbCSLmCQH4UIU84ACn48uxwjyucMwK_wWVloZS99Ija6TT0Qr8yWPeti7JYBlEwelvNYlUTZ_rv5tQTZ7JqQ6H3oNIAjgCk0zGA_mjuh7FMYP92E5O8iA1zAiciFWoMTuFEqFxvhiNq5-i5tpKHdoI03HZphV9FcfsUUrzuu6vLitJfPtQVkvJ9Jxmcfzz8dyBwk2dJylV8Scjv6d22YZpLbpnRh1EQjmki4XCJ5iaz61XHKpHUxusQ',
      'status': 'Published',
      'isDraft': false,
      'statsText': '1.2k students · 14h',
      'statsIcon': Icons.group_rounded,
    },
    {
      'title': 'Modern Art History',
      'description': 'Exploring the seismic shifts in artistic expression from the mid-19th century to today.',
      'imageUrl': 'https://lh3.googleusercontent.com/aida-public/AB6AXuAE7PoZ9LTIoG5uutNqz6Xt6gD2YUvbqq305GgIp-hfioQTmG3nGy3Oueh2HGA6A0lCtP1lUmn17dyLJ2gaphosdX3DwcPgBMk8-EhDHoMWq3WmL5pVaYXw_ohoMasfJV49PFhNeIJ1Tn7i1lyKuPxvoofnIF63eoOciRZ7wDUKCpxezigtDmQajbBiTf0jU1Xi1hIUeXxYJphhgn96vCQIJencrKhiN9HuG1j5gprRDmnP4ETdGnst1cXyPh1pVICDPNqoGZHywo7g',
      'status': 'Published',
      'isDraft': false,
      'statsText': '850 students · 8h',
      'statsIcon': Icons.group_rounded,
    },
    {
      'title': 'Advanced Thermodynamics',
      'description': 'In-depth analysis of entropy, enthalpy, and energy conversion systems.',
      'imageUrl': 'https://lh3.googleusercontent.com/aida-public/AB6AXuCR6hR6bvffsyKtu12OhoJs6jMLIN6XlZ7V_c10UhZ4NnbX-CVQzaD48EjnPlC_ZG76rC7T7d82o5F7bBRsNmeezOeU7-Rmtkn_BXIU88LmGYkaduQGJhsEZHbEYkvc0x_Jpll2b4-3oBvv0b0V711JUu--D242lHRWTM0pPN6dZVKx8kON4x5QfsP4d_kRrzv0gyf6WyyKFkKbkjcHPqQq3PUtcf3K1lrg-j-6jPoH3dZo_H62th4HDgoOU9K8Jzv-2LMxpn0Lcwnj',
      'status': 'Draft',
      'isDraft': true,
      'statsText': '4/12 Modules',
      'statsIcon': Icons.history_edu_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user_data');
    if (userStr != null) {
      setState(() {
        _user = jsonDecode(userStr);
        _isLoading = false;
      });
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null && !_isLoading) {
      return _buildGuestView();
    }

    final topPadding = MediaQuery.of(context).padding.top;

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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 24.0,
                        right: 24.0,
                        bottom: 16.0,
                        top: 16.0 + topPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 32 + topPadding,
            bottom: 32,
          ),
          child: Column(
            children: [
              // Profile Header Section
              _buildGuestHero(),
              const SizedBox(height: 48),

              // Main Action Section: Bento-ish Grid
              _buildGuestBentoGrid(),
              const SizedBox(height: 48),

              // Authentication Prompt Card
              _buildGuestAuthPrompt(),
              const SizedBox(height: 64),

              // Decorative Curator Quote
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Opacity(
                  opacity: 0.4,
                  child: Text(
                    '"Knowledge is a curated gallery of the mind; begin your exhibition today."',
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
              const SizedBox(height: 120), // Bottom nav padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestHero() {
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
              child: const Text(
                'GUEST',
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
        const SizedBox(height: 24),
        const Text(
          'Guest User',
          style: TextStyle(
            fontFamily: 'Mona_Sans',
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'You are currently browsing as a guest',
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
    return Column(
      children: [
        // Join as Teacher Card
        _buildGuestActionCard(
          title: 'Join as Teacher',
          subtitle: 'Share your expertise and build your academic legacy.',
          label: 'Opportunity',
          icon: Icons.school_rounded,
          isPrimary: true,
          onTap: () {
            FeatureComingSoon.show(
              context,
              title: 'Teacher Registration',
              description: 'Become an educator and start sharing your knowledge today.',
              featureName: 'Teacher Ecosystem',
              featureDescription: 'Access tools for course creation and student management.',
              icon: Icons.school_rounded,
              previewIcon: Icons.rocket_launch_rounded,
            );
          },
        ),
        const SizedBox(height: 20),
        // Join as Freelancer Card
        _buildGuestActionCard(
          title: 'Join as Freelancer',
          subtitle: 'Work on your own terms with high-tier educational projects.',
          label: 'Flexibility',
          icon: Icons.work_rounded,
          isPrimary: false,
          onTap: () {
            FeatureComingSoon.show(
              context,
              title: 'Freelancer Portal',
              description: 'Register as a freelancer to participate in educational projects.',
              featureName: 'Klass Freelance',
              featureDescription: 'Flexible work opportunities for experts.',
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
                            isPrimary ? 'Get Started' : 'Learn More',
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          const Text(
            'Return to your journey',
            style: TextStyle(
              fontFamily: 'Mona_Sans',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Access your curated classes and achievements.',
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
                  child: const Text(
                    'Log In',
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
                  child: const Text(
                    'Sign Up',
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'VERIFIED',
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
                _user?['name'] ?? 'Guest User',
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
                      ? 'GUEST'
                      : widget.role == 'freelancer' ? 'FREELANCER' : 'TEACHER',
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
                  '12 Years in Education',
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
                    title: 'Class Dashboard',
                    description:
                        'The Class Dashboard is being refined to provide you with a comprehensive overview of your teaching performance and student engagement metrics.',
                    featureName: 'Performance Analytics',
                    featureDescription:
                        'Real-time data on class participation and curriculum progress.',
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
                  child: const Text(
                    'Class Dashboard',
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
    return Row(
      children: [
        Expanded(
          child: _buildStatCard('06', 'Classes Taught', subtext: 'Active'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('180', 'Student Count', subtext: 'Enrolled'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('24', 'Curriculum Hours', subtext: 'h/week'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Institutional Tools',
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
              'Gradebook &\nAttendance',
            ),
            _buildToolButton(
              Icons.edit_calendar_rounded,
              'Curriculum\nPlanner',
            ),
            _buildToolButton(Icons.campaign_rounded, 'School\nAnnouncements'),
            _buildToolButton(Icons.groups_rounded, 'Parent\nPortal'),
          ],
        ),
      ],
    );
  }

  Widget _buildToolButton(IconData icon, String label) {
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
            description:
                'We are working on bringing ${label.replaceAll('\n', ' ')} directly to your mobile device for seamless institutional management.',
            featureName: 'Institutional Sync',
            featureDescription:
                'Stay connected with your school\'s management systems on the go.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Curriculum Modules',
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
                    'Manage and review your educational curriculum.',
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
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ..._profileModules.map((module) => Padding(
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account & Support',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildAccountSupportItem(
            icon: Icons.settings_rounded,
            label: 'Account Settings',
            isError: false,
          ),
          const SizedBox(height: 12),
          _buildAccountSupportItem(
            icon: Icons.help_rounded,
            label: 'Help Center',
            isError: false,
          ),
          const SizedBox(height: 12),
          _buildAccountSupportItem(
            icon: Icons.work_outline_rounded,
            label: 'Register as Freelancer',
            isError: false,
          ),
          const SizedBox(height: 12),
          if (_user != null)
            _buildAccountSupportItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              isError: true,
            )
          else
            _buildAccountSupportItem(
              icon: Icons.login_rounded,
              label: 'Log In / Create Account',
              isError: false,
            ),
        ],
      ),
    );
  }

  Widget _buildAccountSupportItem({
    required IconData icon,
    required String label,
    required bool isError,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (label == 'Account Settings') {
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
          } else if (label == 'Help Center') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const HelpScreen(),
              ),
            );
          } else if (label == 'Register as Freelancer') {
            if (await requireAuth(context)) {
              if (mounted) {
                FeatureComingSoon.show(
                  context,
                  title: 'Freelancer Registration',
                  description: 'Our freelancer registration portal is currently under construction.',
                  featureName: 'Become a Teacher',
                  featureDescription: 'Share your curicullum and earn from your creations.',
                  icon: Icons.work_rounded,
                  previewIcon: Icons.rocket_launch_rounded,
                );
              }
            }
          } else if (label == 'Logout') {
            _handleLogout();
          } else if (label == 'Log In / Create Account') {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        const Row(
          children: [
            Icon(Icons.work_rounded, color: Color(0xFF53C2B4), size: 22),
            SizedBox(width: 8),
            Text(
              'Freelancer Profile',
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
              const Text(
                'Keahlian',
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
                children: ['Desain Grafis', 'Presentasi', 'Video Editing', 'Konten Edukasi']
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
                child: const Column(
                  children: [
                    Icon(Icons.edit_rounded, color: AppColors.textMuted, size: 24),
                    SizedBox(height: 8),
                    Text(
                      'Edit Keahlian — Segera Hadir',
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
          child: const Column(
            children: [
              Icon(Icons.trending_up_rounded, color: AppColors.textMuted, size: 32),
              SizedBox(height: 12),
              Text(
                'Statistik Portfolio',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Statistik performa dan review dari teacher akan ditampilkan di sini.',
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
}
