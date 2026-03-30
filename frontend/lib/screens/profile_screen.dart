import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../data/mock_data.dart';
import 'account_settings_screen.dart';
import 'help_screen.dart';
import '../widgets/feature_coming_soon.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Stack(
        children: [
          // Layer 2 background (matches Home/Search logic)
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
                          const SizedBox(height: 24),
                          _buildStatsBento(),
                          const SizedBox(height: 32),
                          _buildInstitutionalTools(),
                          const SizedBox(height: 8),
                          _buildTeachingMaterials(),
                          const SizedBox(height: 32),
                          _buildAccountSupport(),
                          const SizedBox(height: 120), // Bottom nav padding
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
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: AppColors.surfaceCard, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  image: const DecorationImage(
                    image: NetworkImage(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuC5VnMYOq0N2jV1mbYtKbSs-WVMbZE_5DYxCzo5nNqe2cWB54X4kx5yyMfK29_rm80S-5kbXUZUHEW37y04uAAmBj5Rj-L5McanjlkZuXslPjFrEsb1-aaECyJUtn5xp2eZVTJeIl02mYJz2uyIsQVKocXclnxH1Ye1GMsontGxBYkjUYAkrRR71qg0lg3Zo9z1gWhSF4AI6b8L7vMBqyyD1pWKcZTYeQEixvO0KfeqHtXvQ7KlRItXuSoJmKhhzo836vjkNSNinkuU',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
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
        const Center(
          child: Text(
            'Dr. Sarah Jenkins',
            style: TextStyle(
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
        const Center(
          child: Text(
            'Senior Mathematics Instructor & Head of STEM',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
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
        ...MockData.profileModules.map((module) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildModuleCard(
                title: module['title'] as String,
                description: module['description'] as String,
                imageUrl: module['imageUrl'] as String,
                status: module['status'] as String,
                isDraft: module['isDraft'] as bool,
                stats: module['stats'] as List<Widget>,
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
    required List<Widget> stats,
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
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                    colorFilter: isDraft
                        ? ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.5),
                            BlendMode.saturation,
                          )
                        : null,
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
                    Row(children: stats),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
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
            icon: Icons.logout_rounded,
            label: 'Logout',
            isError: true,
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
        onTap: () {
          if (label == 'Account Settings') {
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
          } else if (label == 'Help Center') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const HelpScreen(),
              ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isError ? AppColors.red : AppColors.textPrimary,
                    ),
                  ),
                ],
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
}
