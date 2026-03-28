import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import 'account_settings_screen.dart';

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
      child: Container(
        color: AppColors.surface,
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
                    image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuCVWwvza0o2NMoRQf464SP4rJrFCtVIpw7EEgxfKiiQ5JhKlGOdHyjSC2-1CdzUKVrrwm6LGC0pz46SKonWBZpC9i3gZTmfpIu0eQf3J_ZjxaEtuh7WI7HaqE9Z-SwqL8Hum1eAmuQ4jlqfvsEvUbGS5kRg1Ffv7U5g-TwLpeZ1JaCIQcYRmidTMGEtNAvc6Ki-jknKj5cXipM1CvOeFPG91rvDjM4W7sdQRqKJnIU9WI8KwYo0gb_jHp9nq2c_pPqi86FcVC9iMTNo'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: -8,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      Icon(Icons.verified_rounded, color: Colors.white, size: 14),
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
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Dedicated educator specializing in high-impact educational modules. Expert in translating complex scientific theories into accessible digital learning experiences for global audiences.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildTag('QUANTUM PHYSICS', isPrimary: true),
              _buildTag('DIGITAL PEDAGOGY', isPrimary: true),
              _buildTag('CURRICULUM DESIGN', isPrimary: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String text, {bool isPrimary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primaryLight : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isPrimary ? AppColors.primaryDark : AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatsBento() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('48', 'Modules Created')),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('12.4k', 'Students Reached')),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('4.9', 'Avg. Rating', icon: Icons.star_rounded)),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(icon, color: AppColors.primary, size: 20),
              ]
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
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
                    'My Teaching Materials',
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
        _buildModuleCard(
          title: 'Intro to Quantum Physics',
          description: 'A comprehensive journey from classical mechanics to the mysteries of quantum entanglements.',
          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBTGKxSjUWwWvC2HvRdzg_RmvbCSLmCQH4UIU84ACn48uxwjyucMwK_wWVloZS99Ija6TT0Qr8yWPeti7JYBlEwelvNYlUTZ_rv5tQTZ7JqQ6H3oNIAjgCk0zGA_mjuh7FMYP92E5O8iA1zAiciFWoMTuFEqFxvhiNq5-i5tpKHdoI03HZphV9FcfsUUrzuu6vLitJfPtQVkvJ9Jxmcfzz8dyBwk2dJylV8Scjv6d22YZpLbpnRh1EQjmki4XCJ5iaz61XHKpHUxusQ',
          status: 'Published',
          isDraft: false,
          stats: [
            const Icon(Icons.group_rounded, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 4),
            const Text('1.2k', style: _statStyle),
            const SizedBox(width: 16),
            const Icon(Icons.schedule_rounded, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 4),
            const Text('14h', style: _statStyle),
          ],
        ),
        const SizedBox(height: 16),
        _buildModuleCard(
          title: 'Modern Art History',
          description: 'Exploring the seismic shifts in artistic expression from the mid-19th century to today.',
          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAE7PoZ9LTIoG5uutNqz6Xt6gD2YUvbqq305GgIp-hfioQTmG3nGy3Oueh2HGA6A0lCtP1lUmn17dyLJ2gaphosdX3DwcPgBMk8-EhDHoMWq3WmL5pVaYXw_ohoMasfJV49PFhNeIJ1Tn7i1lyKuPxvoofnIF63eoOciRZ7wDUKCpxezigtDmQajbBiTf0jU1Xi1hIUeXxYJphhgn96vCQIJencrKhiN9HuG1j5gprRDmnP4ETdGnst1cXyPh1pVICDPNqoGZHywo7g',
          status: 'Published',
          isDraft: false,
          stats: [
            const Icon(Icons.group_rounded, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 4),
            const Text('850', style: _statStyle),
            const SizedBox(width: 16),
            const Icon(Icons.schedule_rounded, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 4),
            const Text('8h', style: _statStyle),
          ],
        ),
        const SizedBox(height: 16),
        _buildModuleCard(
          title: 'Advanced Thermodynamics',
          description: 'In-depth analysis of entropy, enthalpy, and energy conversion systems.',
          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCR6hR6bvffsyKtu12OhoJs6jMLIN6XlZ7V_c10UhZ4NnbX-CVQzaD48EjnPlC_ZG76rC7T7d82o5F7bBRsNmeezOeU7-Rmtkn_BXIU88LmGYkaduQGJhsEZHbEYkvc0x_Jpll2b4-3oBvv0b0V711JUu--D242lHRWTM0pPN6dZVKx8kON4x5QfsP4d_kRrzv0gyf6WyyKFkKbkjcHPqQq3PUtcf3K1lrg-j-6jPoH3dZo_H62th4HDgoOU9K8Jzv-2LMxpn0Lcwnj',
          status: 'Draft',
          isDraft: true,
          stats: [
            const Icon(Icons.history_edu_rounded, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 4),
            const Text('4/12 Modules', style: _statStyle),
          ],
        ),
      ],
    );
  }

  static const _statStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AppColors.textMuted,
  );

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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                    colorFilter: isDraft
                        ? ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.saturation)
                        : null,
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AccountSettingsScreen()),
            ).then((_) {
              if (mounted) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutQuart,
                );
              }
            });
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