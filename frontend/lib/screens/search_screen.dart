import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:klass_app/l10n/generated/app_localizations.dart';
import '../config/app_colors.dart';

import '../widgets/animated_search_bar.dart';
import '../widgets/skeleton_loaders.dart';
import '../services/home_service.dart';
import '../utils/api_debug_info.dart';

/// Search/Discover Screen — mereplikasi halaman Search dari Klass Next.js.
/// Fitur: Sticky header "Discover", category pills, teacher cards.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _activeCategory = 'all';
  final ScrollController _scrollController = ScrollController();
  bool _isSearching = false;

  final List<Map<String, dynamic>> categories = const [
    {'key': 'all', 'icon': Icons.grid_view_rounded},
    {'key': 'science', 'icon': Icons.science_rounded},
    {'key': 'math', 'icon': Icons.calculate_rounded},
    {'key': 'art', 'icon': Icons.palette_rounded},
    {'key': 'code', 'icon': Icons.code_rounded},
    {'key': 'history', 'icon': Icons.menu_book_rounded},
  ];
  
  final _homeService = HomeService();
  List<Map<String, dynamic>> teachers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
  }

  Future<void> _fetchTeachers({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _homeService.fetchFreelancers(forceRefresh: forceRefresh);
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
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Layer 2 background (matches Home/Settings logic)
            Positioned.fill(
              child: Hero(
                tag: 'layer2_bg',
                child: Container(color: AppColors.background),
              ),
            ),
            
            // Content
            Positioned.fill(
              child: Hero(
                tag: 'content_fade',
                child: RefreshIndicator(
                  onRefresh: () => _fetchTeachers(forceRefresh: true),
                  color: AppColors.primary,
                  backgroundColor: Colors.white,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      // Sticky Header "Discover"
                    AnimatedBuilder(
                      animation: _scrollController,
                      builder: (context, child) {
                        final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
                        final headerOpacity = (offset / 60).clamp(0.0, 1.0);
                        
                        return SliverAppBar(
                          pinned: true,
                          expandedHeight: 140 + topPadding,
                          toolbarHeight: 70,
                          backgroundColor: AppColors.background.withValues(
                            alpha: headerOpacity * 0.92,
                          ),
                          surfaceTintColor: Colors.transparent,
                          automaticallyImplyLeading: false,
                          flexibleSpace: FlexibleSpaceBar(
                            background: Padding(
                              padding: EdgeInsets.only(top: topPadding + 12, left: 24, right: 24, bottom: 20),
                              child: Stack(
                                alignment: Alignment.centerRight,
                                children: [
                                  // Discover Title
                                  Positioned(
                                    left: 0,
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 200),
                                      opacity: _isSearching ? 0.0 : (1 - headerOpacity * 1.5).clamp(0.0, 1.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            localizations.searchDiscoverTitle,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.textPrimary,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            localizations.searchDiscoverSubtitle,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textMuted,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Animated Search Bar
                                  AnimatedSearchBar(
                                    onExpanded: () => setState(() => _isSearching = true),
                                    onCollapsed: () => setState(() => _isSearching = false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          title: AnimatedOpacity(
                            opacity: (headerOpacity > 0.8 && !_isSearching) ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Padding(
                              padding: EdgeInsets.only(top: 16.0),
                              child: Text(
                                localizations.searchDiscoverTitle,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          bottom: PreferredSize(
                            preferredSize: const Size.fromHeight(56),
                            child: _buildCategoryPills(),
                          ),
                        );
                      },
                    ),

                    // Search stats
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              localizations.searchRecommendedTitle,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              localizations.commonViewAll,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Teacher cards
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                      sliver: _isLoading 
                        ? SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildSkeletonCard(),
                                );
                              },
                              childCount: 3,
                            ),
                          )
                        : _error != null
                          ? SliverToBoxAdapter(
                              child: _buildErrorState(),
                            )
                          : teachers.isEmpty
                            ? SliverToBoxAdapter(
                                child: _buildEmptyState(),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    if (index < teachers.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: _buildTeacherCard(teachers[index]),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                  childCount: teachers.length,
                                ),
                              ),
                    ),

                    // Bottom spacing
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 120),
                    ),
                  ],
                ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPills() {
    final localizations = AppLocalizations.of(context)!;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final categoryKey = cat['key'] as String;
          final isActive = _activeCategory == categoryKey;
          return GestureDetector(
            onTap: () => setState(() => _activeCategory = categoryKey),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? AppColors.primary : AppColors.border,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat['icon'] as IconData,
                    size: 16,
                    color: isActive ? Colors.white : AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _categoryLabel(localizations, categoryKey),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher) {
    final localizations = AppLocalizations.of(context)!;

    // ── Null-safe data extraction ──
    // API /marketplace-tasks returns: id, content_id, status, creator_id,
    // attachment_url, content (nested). Map these to UI fields with fallbacks.
    final content = teacher['content'] as Map<String, dynamic>?;
    final displayName = (teacher['name']
        ?? content?['title']
        ?? teacher['creator_id']
      ?? localizations.commonUnknown).toString();
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final role = (teacher['role']
        ?? teacher['status']
      ?? localizations.commonFreelancer).toString();
    final description = (teacher['description']
        ?? content?['description']
      ?? localizations.commonNoDescriptionAvailable).toString();
    final rating = teacher['rating'] ?? '-';
    final isOnline = teacher['online'] == true;

    // Tags: support List<String>, List<dynamic>, or null
    final rawTags = teacher['tags'];
    final List<String> tags;
    if (rawTags is List) {
      tags = rawTags.map((e) => e.toString()).toList();
    } else {
      tags = [];
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Future details navigation
        },
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: AppColors.surfaceLight,
                          border: Border.all(color: AppColors.border, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      if (isOnline)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surfaceCard, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0x1AF59E0B),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded,
                                      size: 14, color: AppColors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$rating',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.amber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          role,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Tags
              if (tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        tag.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              if (tags.isNotEmpty) const SizedBox(height: 16),
              // Description
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // Action row
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Student avatars
                    Row(
                      children: [
                        ...List.generate(
                          3,
                          (i) => Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(left: 0),
                            transform: Matrix4.translationValues(i * -8.0, 0, 0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surfaceLight,
                              border: Border.all(color: AppColors.surfaceCard, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(-16, 0),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surfaceLight,
                              border: Border.all(color: AppColors.surfaceCard, width: 2),
                            ),
                            child: const Center(
                              child: Text(
                                '12+',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          localizations.searchViewProfile,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.primary,
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
    );
  }

  // ─── Skeleton Loading Card (Shimmer) ───────────────────────────────
  Widget _buildSkeletonCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar skeleton
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: AppColors.border.withValues(alpha: 0.25),
                ),
                child: ShimmerEffect(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name skeleton
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Container(
                            height: 16,
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
                        ),
                        const SizedBox(width: 12),
                        // Rating badge skeleton
                        Container(
                          width: 50,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.border.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ShimmerEffect(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Role skeleton
                    Container(
                      height: 12,
                      width: 120,
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tags skeleton
          Row(
            children: [
              _buildTagSkeleton(60),
              const SizedBox(width: 8),
              _buildTagSkeleton(80),
              const SizedBox(width: 8),
              _buildTagSkeleton(55),
            ],
          ),
          const SizedBox(height: 16),
          // Description skeleton lines
          Container(
            height: 12,
            width: double.infinity,
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
          const SizedBox(height: 8),
          Container(
            height: 12,
            width: MediaQuery.of(context).size.width * 0.55,
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
          const SizedBox(height: 16),
          // Bottom action row skeleton
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border.withValues(alpha: 0.3), width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Mini avatar circles skeleton
                Row(
                  children: List.generate(
                    3,
                    (i) => Container(
                      width: 28,
                      height: 28,
                      transform: Matrix4.translationValues(i * -8.0, 0, 0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.border.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 90,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.border.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: ShimmerEffect(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
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
    );
  }

  Widget _buildTagSkeleton(double width) {
    return Container(
      height: 26,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.2),
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

  // ─── Error State (Detailed Debug Info) ─────────────────────────────
  Widget _buildErrorState() {
    final localizations = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.red.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          children: [
            // Error icon with background
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
              style: TextStyle(
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
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            // Debug info container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
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
            // Action buttons row
            Row(
              children: [
                // Copy Debug Info button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyDebugInfo(_error!),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(
                      localizations.commonCopyDebugInfo,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Retry button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _fetchTeachers,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      localizations.commonRetry,
                      style: TextStyle(
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
                        borderRadius: BorderRadius.circular(14),
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

  // ─── Empty State ───────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final localizations = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            // Empty icon with subtle background
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
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
              style: TextStyle(
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
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Refresh button
            OutlinedButton.icon(
              onPressed: () => _fetchTeachers(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                localizations.commonRefresh,
                style: TextStyle(
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(AppLocalizations localizations, String key) {
    switch (key) {
      case 'science':
        return localizations.searchCategoryScience;
      case 'math':
        return localizations.searchCategoryMath;
      case 'art':
        return localizations.searchCategoryArt;
      case 'code':
        return localizations.searchCategoryCode;
      case 'history':
        return localizations.searchCategoryHistory;
      case 'all':
      default:
        return localizations.searchCategoryAll;
    }
  }
}
