import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:klass_app/l10n/generated/app_localizations.dart';
import 'package:klass_app/core/config/app_colors.dart';
import 'package:klass_app/core/network/cancelable_state_mixin.dart';
import 'package:klass_app/core/providers/dio_provider.dart';
import 'package:klass_app/features/freelancer/data/freelancer_service.dart';
import 'package:klass_app/core/utils/auth_guard.dart';

/// Full-screen freelancer profile — navigated from "View Profile" button.
class FreelancerProfileScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> freelancer;

  const FreelancerProfileScreen({
    super.key,
    required this.freelancer,
  });

  @override
  ConsumerState<FreelancerProfileScreen> createState() => _FreelancerProfileScreenState();
}

class _FreelancerProfileScreenState extends ConsumerState<FreelancerProfileScreen>
    with CancelableState {
  late final ScrollController _scrollController;
  Map<String, dynamic>? _detailedProfile;
  List<Map<String, dynamic>> _portfolioItems = [];

  // Derived from widget.freelancer (non-final so detail API can update them)
  late String displayName;
  late String role;
  late String avatarUrl;
  late String price;
  late String rating;
  late int jobCount;
  late List<String> skills;
  late String initial;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _deriveFreelancerData();
    _fetchDetailProfile();
  }

  void _deriveFreelancerData() {
    final f = widget.freelancer;
    final content = f['content'] as Map<String, dynamic>?;

    displayName = (f['name'] ?? content?['title'] ?? f['creator_id'] ?? 'Freelancer').toString();
    initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    role = (f['role'] ?? f['status'] ?? 'Freelancer').toString();
    rating = (f['rating'] ?? '-').toString();
    jobCount = (f['job_count'] ?? f['jobs'] ?? 0) as int;

    String src = (f['avatar_url'] ?? f['avatarPath'] ?? '').toString();
    if (src.contains('.r2.dev')) {
      src = 'https://wsrv.nl/?url=${src.replaceAll('https://', '')}';
    }
    avatarUrl = src;

    final rawPrice = (f['price'] ?? f['rate'] ?? '--').toString();
    price = rawPrice.replaceAll(RegExp(r'\/topik$|\/jam$'), '').trim();

    final rawTags = f['tags'];
    if (rawTags is List) {
      skills = rawTags.map((e) => e.toString()).toList();
    } else {
      skills = [];
    }
  }

  Future<void> _fetchDetailProfile() async {
    final userId = widget.freelancer['user_id']?.toString() ??
        widget.freelancer['id']?.toString() ??
        '';
    if (userId.isEmpty) {
      return;
    }

    try {
      final service = FreelancerService(ref.read(dioProvider));
      final profile = await service.fetchFreelancerProfile(
        userId: userId,
        cancelToken: cancelToken,
      );
      if (mounted) {
        setState(() {
          _detailedProfile = profile;

          // Update displayed data from detail response
          if (profile['display_name'] != null && profile['display_name'].toString().isNotEmpty) {
            displayName = profile['display_name'].toString();
            initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
          }
          if (profile['role'] != null && profile['role'].toString().isNotEmpty) {
            role = profile['role'].toString();
          }
          if (profile['avatar_url'] != null && profile['avatar_url'].toString().isNotEmpty) {
            avatarUrl = profile['avatar_url'].toString();
            if (avatarUrl.contains('.r2.dev')) {
              avatarUrl = 'https://wsrv.nl/?url=${avatarUrl.replaceAll('https://', '')}';
            }
          }
          if (profile['price'] != null && profile['price'].toString().isNotEmpty) {
            price = profile['price'].toString().replaceAll(RegExp(r'\/topik$|\/jam$'), '').trim();
          }
          if (profile['rating'] != null) {
            rating = profile['rating'].toString();
          }
          if (profile['job_count'] != null) {
            jobCount = (profile['job_count'] as num).toInt();
          }

          // Update skills from detail response if available
          final rawSkills = profile['skills'];
          if (rawSkills is List && rawSkills.isNotEmpty) {
            skills = rawSkills.map((e) => e.toString()).toList();
          }

          // Update portfolio
          final rawPortfolio = profile['portfolio'];
          if (rawPortfolio is List) {
            _portfolioItems = rawPortfolio.cast<Map<String, dynamic>>();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          // Detail fetch failed; screen continues with list data
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Main scrollable content
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildBioSection()),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
                SliverToBoxAdapter(child: _buildDivider()),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
                if (_portfolioItems.isNotEmpty)
                  SliverToBoxAdapter(child: _buildPortfolioSection()),
                if (_portfolioItems.isNotEmpty) const SliverToBoxAdapter(child: SizedBox(height: 32)),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),

            // Sticky top bar
            _buildStickyAppBar(),

            // Bottom CTA
            _buildBottomCTA(),
          ],
        ),
      ),
    );
  }

  // ─── Sticky App Bar ────────────────────────────────────────────

  Widget _buildStickyAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _scrollController,
        builder: (context, child) {
          final offset = _scrollController.hasClients
              ? _scrollController.offset
              : 0.0;
          final headerOpacity = (offset / 80).clamp(0.0, 1.0);
          final titleOpacity = ((offset - 40) / 40).clamp(0.0, 1.0);
          final topPad = MediaQuery.of(context).padding.top;
          const barHeight = 44.0;

          return Container(
            padding: EdgeInsets.only(top: topPad),
            height: topPad + barHeight,
            color: Colors.white.withValues(alpha: headerOpacity * 0.95),
            child: Stack(
              children: [
                // Back button — vertically centered in the bar area
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: headerOpacity > 0.5
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: headerOpacity > 0.5
                            ? Border.all(color: AppColors.border.withValues(alpha: 0.5))
                            : null,
                        boxShadow: headerOpacity > 0.5
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                ),
                              ]
                            : [],
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 22,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                // Title (appears on scroll)
                Center(
                  child: AnimatedOpacity(
                    opacity: titleOpacity,
                    duration: const Duration(milliseconds: 150),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 56),
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Header (Banner + Avatar) ──────────────────────────────────

  Widget _buildHeader() {
    final topPadding = MediaQuery.of(context).padding.top;
    final detail = _detailedProfile;

    return Column(
      children: [
        // ── Banner ──
        Container(
          height: topPadding + 120,
          width: double.infinity,
          color: AppColors.textPrimary,
          // Banner content with dot pattern
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Status bar area (transparent, just for spacing)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topPadding,
                child: Container(color: Colors.transparent),
              ),
              // Actual 120px banner below status bar
              Positioned(
                top: topPadding,
                left: 0,
                right: 0,
                bottom: 0,
                child: Opacity(
                  opacity: 0.08,
                  child: CustomPaint(
                    painter: _DotPatternPainter(),
                  ),
                ),
              ),
              // Avatar — positioned to extend 48px below banner bottom
              Positioned(
                bottom: -48,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildAvatarCircle(detail),
                ),
              ),
            ],
          ),
        ),
        // Spacer to push bio below the avatar
        const SizedBox(height: 64),
      ],
    );
  }

  Widget _buildAvatarCircle(Map<String, dynamic>? detail) {
    final hasImage = avatarUrl.startsWith('http');

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A0A192F),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Profile image or fallback
          ClipOval(
            child: hasImage
                ? CachedNetworkImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    width: 96,
                    height: 96,
                    httpHeaders: const {'User-Agent': 'Mozilla/5.0'},
                    errorWidget: (context, url, error) => _buildAvatarFallback(),
                  )
                : _buildAvatarFallback(),
          ),
          // Online indicator
          if (detail?['verified'] == true)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      width: 96,
      height: 96,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  // ─── Bio Section ───────────────────────────────────────────────

  Widget _buildBioSection() {
    final detail = _detailedProfile;
    final bio = detail?['bio'] as String? ?? '';
    final location = detail?['location'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Name
          Text(
            displayName,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // Role
          Text(
            role,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Location + Rating row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (location.isNotEmpty) ...[
                Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  location,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Icon(
                Icons.star_rounded,
                size: 16,
                color: AppColors.amber,
              ),
              const SizedBox(width: 4),
              Text(
                rating,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '($jobCount jobs)',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Bio
          if (bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                bio,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 20),
          // Skills / Tags
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: skills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  skill,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Divider ───────────────────────────────────────────────────

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(height: 1, color: AppColors.border),
    );
  }

  // ─── Portfolio Section ──────────────────────────────────────────

  Widget _buildPortfolioSection() {
    final localizations = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Work',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                localizations.commonViewAll,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 24, right: 24),
            itemCount: _portfolioItems.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final item = _portfolioItems[index];
              return _buildPortfolioItem(
                imageUrl: item['image_url'] as String? ?? '',
                title: item['title'] as String? ?? '',
                category: item['category'] as String? ?? '',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolioItem({
    required String imageUrl,
    required String title,
    required String category,
  }) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 160,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x0A0A192F),
                  blurRadius: 12,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.startsWith('http')
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    httpHeaders: const {'User-Agent': 'Mozilla/5.0'},
                    errorWidget: (context, url, error) => Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 36,
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 36,
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            category,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── Bottom CTA ────────────────────────────────────────────────

  Widget _buildBottomCTA() {
    final localizations = AppLocalizations.of(context)!;
    final firstName = displayName.split(' ').first;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (await requireAuth(context, ref)) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        localizations.freelancerDetailsHire(firstName),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label:                  Text(
                        localizations.freelancerDetailsHire(firstName),
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Dot Pattern Painter ─────────────────────────────────────────

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    const spacing = 24.0;
    const radius = 1.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x + 2, y + 2), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
