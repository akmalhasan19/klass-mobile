import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:klass_app/l10n/generated/app_localizations.dart';
import '../config/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Freelancer Home Screen — Dashboard utama untuk akun Freelancer.
/// Menampilkan welcome message dan overview placeholder.
class FreelancerHomeScreen extends StatefulWidget {
  static const Key settingsButtonKey = Key('freelancer_home_settings_button');

  final VoidCallback? onSettingsTap;

  const FreelancerHomeScreen({super.key, this.onSettingsTap});

  @override
  State<FreelancerHomeScreen> createState() => _FreelancerHomeScreenState();
}

class _FreelancerHomeScreenState extends State<FreelancerHomeScreen> {
  String _userName = '';

  AppLocalizations _localizations() {
    return AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));
  }

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user_data');
    if (userStr != null) {
      final user = jsonDecode(userStr) as Map<String, dynamic>;
      if (mounted) {
        setState(() => _userName = (user['name'] ?? '').toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = _localizations();
    final topPadding = MediaQuery.of(context).padding.top;
    final displayName = _userName.isEmpty
        ? localizations.commonFreelancer
        : _userName;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                    Color(0xFF0F3460),
                  ],
                ),
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE94560).withValues(alpha: 0.08),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(top: topPadding > 0 ? 8 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${localizations.freelancerHomeGreeting(displayName)} 👋',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              localizations.freelancerHomeDashboardLabel,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF53C2B4),
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                        if (widget.onSettingsTap != null)
                          GestureDetector(
                            key: FreelancerHomeScreen.settingsButtonKey,
                            onTap: widget.onSettingsTap,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.settings_rounded,
                                color: Colors.white70,
                                size: 24,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Quick Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(child: _buildStatCard('0', localizations.freelancerHomeActiveProjects, Icons.work_rounded)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('0', localizations.freelancerHomePendingOffers, Icons.mail_rounded)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('—', localizations.freelancerHomeRating, Icons.star_rounded)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Coming Soon Banner
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.2),
                            const Color(0xFF53C2B4).withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.rocket_launch_rounded,
                              size: 36,
                              color: Color(0xFF53C2B4),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            localizations.freelancerHomeBannerTitle,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            localizations.freelancerHomeBannerDescription,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Feature Preview Cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.freelancerHomeSectionTitle,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFeaturePreview(
                          Icons.search_rounded,
                          localizations.freelancerHomeFeatureSearchProjects,
                          localizations.freelancerHomeFeatureSearchProjectsDescription,
                          const Color(0xFF3498DB),
                        ),
                        const SizedBox(height: 12),
                        _buildFeaturePreview(
                          Icons.cases_rounded,
                          localizations.freelancerHomeFeaturePortfolio,
                          localizations.freelancerHomeFeaturePortfolioDescription,
                          const Color(0xFFE94560),
                        ),
                        const SizedBox(height: 12),
                        _buildFeaturePreview(
                          Icons.payments_rounded,
                          localizations.freelancerHomeFeaturePayments,
                          localizations.freelancerHomeFeaturePaymentsDescription,
                          const Color(0xFF2ECC71),
                        ),
                        const SizedBox(height: 12),
                        _buildFeaturePreview(
                          Icons.chat_rounded,
                          localizations.freelancerHomeFeatureMessages,
                          localizations.freelancerHomeFeatureMessagesDescription,
                          const Color(0xFFF39C12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF53C2B4), size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePreview(IconData icon, String title, String desc, Color color) {
    final localizations = _localizations();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              localizations.featureComingSoonBadge,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white54,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
