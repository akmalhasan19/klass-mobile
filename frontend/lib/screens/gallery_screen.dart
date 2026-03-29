import 'package:flutter/material.dart';
import 'dart:ui';
import '../config/app_colors.dart';
import '../widgets/filter_modal.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Sticky Search Header
          _buildSearchHeader(),

          // Category: RECENT
          _buildCategoryHeader('Recent'),
          _buildRecentGrid(),

          // Category: MATH
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          _buildCategoryHeader('Math', itemCount: 12),
          _buildMathGrid(),

          // Category: HISTORY
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          _buildCategoryHeader('History', itemCount: 8),
          _buildHistoryGrid(),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: AppColors.textPrimary,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Container(
          height: 44,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search materials...',
              hintStyle: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textMuted.withValues(alpha: 0.6),
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppColors.textMuted.withValues(alpha: 0.6),
                size: 20,
              ),
              suffixIcon: IconButton(
                onPressed: () => FilterModal.show(context),
                icon: Icon(
                  Icons.tune_rounded,
                  color: AppColors.textMuted.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String title, {int? itemCount}) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _CategoryHeaderDelegate(title: title, itemCount: itemCount),
    );
  }

  Widget _buildRecentGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        delegate: SliverChildListDelegate([
          _buildImageItem('assets/images/ppt_design_3.jpg', 'PDF'),
          _buildImageItem(
            'assets/images/infographic_preview_health_1773981088610.png',
            'IMAGE',
          ),
          _buildGradientItem(
            'Lesson Plan: Week 4',
            Icons.description_rounded,
            AppColors.primary,
            'ARTICLE',
          ),
        ]),
      ),
    );
  }

  Widget _buildMathGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        delegate: SliverChildListDelegate([
          _buildImageItem(
            'assets/images/square_preview_math_1773981103817.png',
            'IMAGE',
          ),
          _buildImageItem(
            'assets/images/ppt_design_3.jpg',
            'PDF',
          ), // Placeholder
          _buildGradientBoxItem('∑', 'Calculus Basics', Colors.blue, 'ARTICLE'),
          _buildImageItem(
            'assets/images/infographic_preview_health_1773981088610.png',
            'IMAGE',
          ), // Placeholder
        ]),
      ),
    );
  }

  Widget _buildHistoryGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        delegate: SliverChildListDelegate([
          _buildImageItem(
            'assets/images/ppt_design_3.jpg',
            'IMAGE',
          ), // Vintage map placeholder
          _buildImageItem(
            'assets/images/ppt_design_3.jpg',
            'PDF',
          ), // Document placeholder
          _buildImageItem(
            'assets/images/ppt_design_3.jpg',
            'IMAGE',
          ), // Rome placeholder
          _buildGradientItem(
            'WW2 Timeline',
            Icons.menu_book_rounded,
            Colors.amber,
            'ARTICLE',
          ),
          _buildImageItem(
            'assets/images/ppt_design_3.jpg',
            'IMAGE',
          ), // Hieroglyphs placeholder
        ]),
      ),
    );
  }

  Widget _buildImageItem(String imagePath, String type) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: AppColors.border),
          ),
          Positioned(bottom: 6, right: 6, child: _buildTypeIcon(type)),
        ],
      ),
    );
  }

  Widget _buildGradientItem(
    String title,
    IconData icon,
    Color color,
    String type,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.2)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color.withValues(alpha: 0.8), size: 28),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color.withValues(alpha: 0.9),
                  height: 1.1,
                ),
              ),
            ],
          ),
          Positioned(bottom: 0, right: 0, child: _buildTypeIcon(type)),
        ],
      ),
    );
  }

  Widget _buildGradientBoxItem(
    String symbol,
    String title,
    Color color,
    String type,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                symbol,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          Positioned(bottom: 0, right: 0, child: _buildTypeIcon(type)),
        ],
      ),
    );
  }

  Widget _buildTypeIcon(String type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'PDF':
        iconData = Icons.picture_as_pdf_rounded;
        iconColor = AppColors.red;
        break;
      case 'IMAGE':
        iconData = Icons.image_rounded;
        iconColor = Colors.blue;
        break;
      default:
        iconData = Icons.article_rounded;
        iconColor = Colors.blue.shade700;
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Icon(iconData, color: iconColor, size: 14),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final int? itemCount;

  _CategoryHeaderDelegate({required this.title, this.itemCount});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(
              alpha: overlapsContent ? 0.5 : 0.0,
            ),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: AppColors.textMuted,
            ),
          ),
          if (itemCount != null)
            Text(
              '$itemCount items',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) {
    return oldDelegate.title != title || oldDelegate.itemCount != itemCount;
  }
}
