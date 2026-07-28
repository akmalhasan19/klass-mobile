import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:klass_app/l10n/generated/app_localizations.dart';
import 'package:klass_app/core/config/app_colors.dart';


import 'package:klass_app/shared/widgets/skeleton_loaders.dart';
import 'package:klass_app/features/home/data/home_service.dart';
import 'package:klass_app/features/freelancer/screens/freelancer_profile_screen.dart';
import 'package:klass_app/core/utils/api_debug_info.dart';
import 'package:klass_app/core/network/cancelable_state_mixin.dart';
import 'package:klass_app/core/providers/dio_provider.dart';

/// Search/Discover Screen — Talent Discovery UI.
/// Sticky search bar, horizontal category pills, talent cards.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with CancelableState {
  String _activeCategory = 'all';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final List<String> categories = const [
    'all',
    'product_design',
    'branding',
    'development',
    'illustration',
  ];

  late final HomeService _homeService;
  List<Map<String, dynamic>> teachers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _homeService = HomeService(ref.read(dioProvider));
    _fetchTeachers();
  }

  Future<void> _fetchTeachers({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _homeService.fetchFreelancers(
        forceRefresh: forceRefresh,
        cancelToken: cancelToken,
      );
      if (mounted) {
        setState(() {
          teachers = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _localizeErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  String _localizeErrorMessage(Object error) {
    return ApiDebugInfo.localize(error, AppLocalizations.of(context));
  }

  Future<void> _copyDebugInfo(String message) async {
    final localizations = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          localizations.commonDebugInfoCopied,
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

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: AppColors.background,
          child: Column(
            children: [
              // Sticky Header
              _buildStickyHeader(topPadding),
              // Main Feed
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _fetchTeachers(forceRefresh: true),
                  color: AppColors.primary,
                  backgroundColor: Colors.white,
                  child: _buildMainFeed(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Sticky Header ────────────────────────────────────────────────
  Widget _buildStickyHeader(double topPadding) {
    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 12,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Search Bar
          _buildSearchBar(),
          const SizedBox(height: 16),
          // Category Pills
          _buildCategoryPills(),
        ],
      ),
    );
  }

  // ─── Search Bar (Always visible, rounded) ─────────────────────────
  Widget _buildSearchBar() {
    final localizations = AppLocalizations.of(context)!;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            Icons.search_rounded,
            size: 22,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: localizations.animatedSearchHint,
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Category Pills (Horizontal scroll) ──────────────────────────
  Widget _buildCategoryPills() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final key = categories[index];
          final isActive = _activeCategory == key;
          return GestureDetector(
            onTap: () => setState(() => _activeCategory = key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              height: 36,
              decoration: BoxDecoration(
                color: isActive ? AppColors.textPrimary : AppColors.background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isActive
                      ? AppColors.textPrimary
                      : AppColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _categoryLabel(key),
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Main Feed ───────────────────────────────────────────────────
  Widget _buildMainFeed() {
    final localizations = AppLocalizations.of(context)!;

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        // Section Title
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    localizations.searchRecommendedTitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  localizations.commonViewAll,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Talent Cards
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: _isLoading
              ? SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildSkeletonCard(),
                    ),
                    childCount: 3,
                  ),
                )
              : _error != null
                  ? SliverToBoxAdapter(child: _buildErrorState())
                  : teachers.isEmpty
                      ? SliverToBoxAdapter(child: _buildEmptyState())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index < teachers.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildTalentCard(teachers[index]),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                            childCount: teachers.length,
                          ),
                        ),
        ),

        // Bottom spacing
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ─── Talent Card ─────────────────────────────────────────────────
  Widget _buildTalentCard(Map<String, dynamic> teacher) {
    final localizations = AppLocalizations.of(context)!;

    final content = teacher['content'] as Map<String, dynamic>?;
    final displayName = (teacher['name'] ??
            content?['title'] ??
            teacher['creator_id'] ??
            localizations.commonUnknown)
        .toString();
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final role = (teacher['role'] ??
            teacher['status'] ??
            localizations.commonFreelancer)
        .toString();
    final rating = teacher['rating'] ?? '-';
    final jobCount = teacher['job_count'] ?? teacher['jobs'] ?? 0;
    final rawPrice = (teacher['price'] ?? teacher['rate'] ?? '--').toString();
    final price = rawPrice.replaceAll(RegExp(r'\/topik$|\/jam$'), '').trim();

    final rawTags = teacher['tags'];
    final List<String> tags;
    if (rawTags is List) {
      tags = rawTags.map((e) => e.toString()).toList();
    } else {
      tags = [];
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A0A192F),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0x08000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Avatar, Info, Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Builder(
                builder: (context) {
                  String avatarSource = (teacher['avatar_url'] ?? teacher['avatarPath'] ?? '').toString();
                  if (avatarSource.contains('.r2.dev')) {
                    avatarSource = 'https://wsrv.nl/?url=${avatarSource.replaceAll('https://', '')}';
                  }
                  final isNetworkAvatar = avatarSource.startsWith('http');

                  return Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: avatarSource.isNotEmpty
                        ? ClipOval(
                            child: isNetworkAvatar
                                ? CachedNetworkImage(
                                    imageUrl: avatarSource,
                                    fit: BoxFit.cover,
                                    httpHeaders: const {'User-Agent': 'Mozilla/5.0'},
                                    errorWidget: (context, url, error) => Center(
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  )
                                : Image.asset(
                                    avatarSource,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                          )
                        : Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                  );
                },
              ),

              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Rating row
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: AppColors.amber,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$rating',
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
                  ],
                ),
              ),
              // Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        price,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Text(
                      '/hr',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Tags
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          // View Profile button
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => FreelancerProfileScreen(
                      freelancer: teacher,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                localizations.searchViewProfile,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Skeleton Card ───────────────────────────────────────────────
  Widget _buildSkeletonCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar skeleton
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.border.withValues(alpha: 0.25),
                ),
                child: ShimmerEffect(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Container(
                      height: 16,
                      width: 140,
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ShimmerEffect(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Role
                    Container(
                      height: 12,
                      width: 100,
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ShimmerEffect(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Rating
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ShimmerEffect(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Price skeleton
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      height: 18,
                      width: 40,
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ShimmerEffect(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 10,
                      width: 20,
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ShimmerEffect(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Tags skeleton
          Row(
            children: [
              _buildTagSkeleton(65),
              const SizedBox(width: 8),
              _buildTagSkeleton(90),
            ],
          ),
          const SizedBox(height: 14),
          // Button skeleton
          Container(
            height: 40,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ShimmerEffect(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagSkeleton(double width) {
    return Container(
      height: 28,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ShimmerEffect(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
      ),
    );
  }

  // ─── Error State ─────────────────────────────────────────────────
  Widget _buildErrorState() {
    final localizations = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.red.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: AppColors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              localizations.searchErrorTitle,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localizations.searchErrorDescription,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _error!,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyDebugInfo(_error!),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(
                      localizations.commonCopyDebugInfo,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _fetchTeachers,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      localizations.commonRetry,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty State ─────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final localizations = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                Icons.person_search_rounded,
                size: 40,
                color: AppColors.textMuted.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              localizations.searchEmptyTitle,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                localizations.searchEmptyDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _fetchTeachers(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                localizations.commonRefresh,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Category Label ──────────────────────────────────────────────
  String _categoryLabel(String key) {
    switch (key) {
      case 'product_design':
        return 'Product Design';
      case 'branding':
        return 'Branding';
      case 'development':
        return 'Development';
      case 'illustration':
        return 'Illustration';
      case 'all':
      default:
        return 'All';
    }
  }
}
