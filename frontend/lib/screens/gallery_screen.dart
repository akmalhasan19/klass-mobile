import 'package:flutter/material.dart';
import 'dart:ui';
import '../config/app_colors.dart';
import '../widgets/filter_modal.dart';
import '../services/gallery_service.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GalleryService _galleryService = GalleryService();
  
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _galleryItems = [];

  @override
  void initState() {
    super.initState();
    _fetchGallery();
  }

  Future<void> _fetchGallery() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _galleryService.fetchGallery();
      if (mounted) {
        setState(() {
          _galleryItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load gallery';
          _isLoading = false;
        });
      }
    }
  }

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

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(fontFamily: 'Inter', color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchGallery,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_galleryItems.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported_rounded, color: AppColors.border, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'No materials in Gallery',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._buildDynamicCategoryGrids(),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  List<Widget> _buildDynamicCategoryGrids() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in _galleryItems) {
      final cat = (item['category'] ?? 'Miscellaneous').toString();
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    final List<Widget> slivers = [];
    for (var entry in grouped.entries) {
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
      slivers.add(_buildCategoryHeader(entry.key, itemCount: entry.value.length));
      slivers.add(_buildDynamicGrid(entry.value));
    }
    return slivers;
  }

  Widget _buildDynamicGrid(List<Map<String, dynamic>> items) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            final type = (item['type'] ?? 'IMAGE').toString().toUpperCase();
            final url = item['url'] ?? item['image_url'] ?? item['cover_image'] ?? '';
            final title = item['title'] ?? 'Untitled';

            if (type == 'ARTICLE') {
              return _buildGradientItem(title, Icons.description_rounded, AppColors.primary, type);
            } else {
              if (url.isEmpty) {
                return _buildGradientItem(title, Icons.broken_image_rounded, AppColors.textMuted, type);
              }
              return _buildImageItem(url, type);
            }
          },
          childCount: items.length,
        ),
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

  // Grids replaced dynamically

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
          imagePath.startsWith('http')
              ? Image.network(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: AppColors.border, child: const Icon(Icons.broken_image_rounded, color: Colors.grey)),
                )
              : Image.asset(
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
