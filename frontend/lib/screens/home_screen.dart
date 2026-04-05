import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../widgets/prompt_input_widget.dart';
import '../widgets/project_suggestion_card.dart';
import '../widgets/bleeding_horizontal_list.dart';
import '../widgets/layer2_white_clipper.dart';
import '../widgets/project_details_bottom_sheet.dart';
import '../widgets/freelancer_details_bottom_sheet.dart';
import '../config/animations.dart';
import '../services/home_service.dart';
import '../utils/auth_guard.dart';

import '../widgets/skeleton_loaders.dart';

/// Home Screen — mereplikasi halaman utama Klass.
/// Fitur: Sticky header "Klass", prompt input, project suggestions,
/// project recommendations (bleed), top freelancers (bleed).
class HomeScreen extends StatefulWidget {
  final VoidCallback? onSettingsTap;
  final bool shouldFocusPrompt;

  const HomeScreen({
    super.key,
    this.onSettingsTap,
    this.shouldFocusPrompt = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocusNode = FocusNode();

  final _homeService = HomeService();
  List<Map<String, dynamic>> projects = [];
  List<Map<String, dynamic>> freelancers = [];
  List<Map<String, dynamic>> _sections = [];
  bool _isProjectsLoading = true;
  bool _isFreelancersLoading = true;
  bool _isSectionsLoading = true;
  String? _projectsError;
  String? _freelancersError;

  @override
  void initState() {
    super.initState();
    if (widget.shouldFocusPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptFocusNode.requestFocus();
      });
    }
    _fetchData();
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _isProjectsLoading = true;
        _isFreelancersLoading = true;
        _isSectionsLoading = true;
        _projectsError = null;
        _freelancersError = null;
      });
    }

    List<Map<String, dynamic>> fetchedProjects = [];
    List<Map<String, dynamic>> fetchedFreelancers = [];
    List<Map<String, dynamic>> fetchedSections = [];

    String? projectsError;
    String? freelancersError;

    try {
      fetchedSections = await _homeService.fetchHomepageSections(forceRefresh: forceRefresh);
      // Sort by position
      fetchedSections.sort((a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0));
    } catch (e) {
      debugPrint('Error fetching homepage sections: $e');
    }

    try {
      fetchedProjects = await _homeService.fetchProjects(forceRefresh: forceRefresh);
    } catch (e) {
      projectsError = _normalizeErrorMessage(e);
    }

    try {
      fetchedFreelancers = await _homeService.fetchFreelancers(forceRefresh: forceRefresh);
    } catch (e) {
      freelancersError = _normalizeErrorMessage(e);
    }

    if (!mounted) return;

    setState(() {
      projects = fetchedProjects;
      freelancers = fetchedFreelancers;
      _sections = fetchedSections;
      _projectsError = projectsError;
      _freelancersError = freelancersError;
      _isProjectsLoading = false;
      _isFreelancersLoading = false;
      _isSectionsLoading = false;
    });
  }

  Future<void> _retryProjects() async {
    if (mounted) {
      setState(() {
        _isProjectsLoading = true;
        _projectsError = null;
      });
    }

    try {
      final fetchedProjects = await _homeService.fetchProjects();
      if (!mounted) return;
      setState(() {
        projects = fetchedProjects;
        _projectsError = null;
        _isProjectsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _projectsError = _normalizeErrorMessage(e);
        _isProjectsLoading = false;
      });
    }
  }

  Future<void> _retryFreelancers() async {
    if (mounted) {
      setState(() {
        _isFreelancersLoading = true;
        _freelancersError = null;
      });
    }

    try {
      final fetchedFreelancers = await _homeService.fetchFreelancers();
      if (!mounted) return;
      setState(() {
        freelancers = fetchedFreelancers;
        _freelancersError = null;
        _isFreelancersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _freelancersError = _normalizeErrorMessage(e);
        _isFreelancersLoading = false;
      });
    }
  }

  String _normalizeErrorMessage(Object error) {
    final raw = error.toString();
    const exceptionPrefix = 'Exception: ';
    if (raw.startsWith(exceptionPrefix)) {
      return raw.substring(exceptionPrefix.length);
    }
    return raw;
  }

  Future<void> _copyDebugInfo(String message) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Debug info copied to clipboard')),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    _promptFocusNode.dispose();
    super.dispose();
  }

  List<Widget> _buildDynamicSections() {
    // If sections from API are empty or still loading, show default order with skeletons if needed
    if (_sections.isEmpty) {
      if (_isSectionsLoading) {
        // Just show skeletons for defaults
        return [
          _buildProjectsSection('...'),
          const SizedBox(height: 32),
          _buildFreelancersSection('...'),
        ];
      }
      // Fallback if API fails
      return [
        _buildProjectsSection('Project Recommendations'),
        const SizedBox(height: 32),
        _buildFreelancersSection('Top Freelancers'),
      ];
    }

    List<Widget> widgets = [];
    for (var section in _sections) {
      if (section['is_enabled'] == false) continue;

      final key = section['key'];
      final label = section['label'] ?? 'Untitled';

      if (key == 'project_recommendations' || key == 'projects') {
        widgets.add(_buildProjectsSection(label));
        widgets.add(const SizedBox(height: 32));
      } else if (key == 'top_freelancers' || key == 'freelancers') {
        widgets.add(_buildFreelancersSection(label));
        widgets.add(const SizedBox(height: 32));
      }
    }
    return widgets;
  }

  Widget _buildProjectsSection(String title) {
    return BleedingHorizontalList(
      title: title,
      height: 260,
      children: _isProjectsLoading
          ? List.generate(
              3,
              (index) => ProjectSuggestionSkeleton(
                ratio: index == 1 ? 'infographic' : (index == 2 ? 'square' : 'ppt'),
              ),
            )
          : _projectsError != null
              ? [
                  _buildErrorPlaceholder(_projectsError!, onRetry: _retryProjects),
                ]
              : projects.isEmpty
                  ? [
                      _buildEmptyPlaceholder('Belum ada project', icon: Icons.folder_open_rounded),
                    ]
                  : projects.map((p) {
                      final imageCandidate = (p['media_url'] ?? p['imagePath'] ?? p['image'] ?? '').toString();
                      final isNetworkImage = imageCandidate.startsWith('http');

                      return ProjectSuggestionCard(
                        title: p['title'] ?? 'Untitled',
                        author: p['author'] ?? p['author_name'] ?? 'By Unknown',
                        ratio: p['ratio'] ?? 'ppt',
                        imageUrl: isNetworkImage ? imageCandidate : null,
                        imagePath: (!isNetworkImage && imageCandidate.isNotEmpty) ? imageCandidate : null,
                        sourceBadge: p['source_type'] == 'admin_upload' ? '★ Curated' : null,
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) {
                              return ProjectDetailsBottomSheet(
                                project: p,
                                onRecreate: (description) async {
                                  if (await requireAuth(context)) {
                                    _promptController.text = description;
                                  }
                                },
                              );
                            },
                          );
                        },
                      );
                    }).toList(),
    );
  }

  Widget _buildFreelancersSection(String title) {
    return BleedingHorizontalList(
      title: title,
      height: 140,
      itemSpacing: 25,
      children: _isFreelancersLoading
          ? List.generate(5, (_) => const FreelancerSkeleton())
          : _freelancersError != null
              ? [
                  _buildErrorPlaceholder(_freelancersError!, onRetry: _retryFreelancers),
                ]
              : freelancers.isEmpty
                  ? [
                      _buildEmptyPlaceholder('Belum ada freelancer', icon: Icons.group_off_rounded),
                    ]
                  : freelancers.map((f) {
                      return _buildFreelancerCard(f);
                    }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Kita gunakan topPadding agar hijau Layer 1 meliputi area status bar,
    // plus tambahan sedikit agar garis luarnya terlihat jelas
    final topPadding = MediaQuery.of(context).padding.top;
    final double topCutOffY = topPadding > 0 ? topPadding + 8.0 : 24.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: GestureDetector(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Stack(
          children: [
          // -----------------------------------------------------------------
          // Layer 1 (Back-most): Background Hijau Utama & Lingkaran Coklat
          // -----------------------------------------------------------------
          Positioned.fill(
            child: Container(
              color: AppColors.primary,
              child: Stack(
                children: [
                  // Lingkaran coklat (yang tadinya di dalam TopRightAccent)
                  Positioned(
                    top: -60,
                    right: -35,
                    child: Transform.rotate(
                      angle: 28 * 3.1415926535 / 180,
                      child: Container(
                        width: 165,
                        height: 120,
                        decoration: const BoxDecoration(
                          color: AppColors.brown,
                          borderRadius: BorderRadius.all(
                            Radius.elliptical(82.5, 60),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // -----------------------------------------------------------------
          // Layer 2a (Middle-Back): Background Putih dengan Custom Shape
          // Bergerak naik tersinkronisasi dengan konten (scroll offset).
          // -----------------------------------------------------------------
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _scrollController,
              builder: (context, child) {
                double offset = 0;
                if (_scrollController.hasClients && _scrollController.positions.isNotEmpty) {
                  offset = _scrollController.positions.first.pixels;
                  if (offset < 0) offset = 0;
                }
                return Transform.translate(
                  offset: Offset(0, -offset),
                  child: child,
                );
              },
              child: Hero(
                tag: 'layer2_bg',
                flightShuttleBuilder: (
                  BuildContext flightContext,
                  Animation<double> animation,
                  HeroFlightDirection flightDirection,
                  BuildContext fromHeroContext,
                  BuildContext toHeroContext,
                ) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      final currentCutOff = Tween<double>(
                        begin: topCutOffY,
                        end: 0.0,
                      ).evaluate(animation);
                      return Material(
                        color: Colors.transparent,
                        child: ClipPath(
                          clipper: Layer2WhiteClipper(cutOffY: currentCutOff),
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: AppColors.background,
                          ),
                        ),
                      );
                    },
                  );
                },
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      ClipPath(
                        clipper: Layer2WhiteClipper(cutOffY: topCutOffY),
                        child: Container(
                          width: double.infinity,
                          height:
                              250, // Cukup untuk mencakup tinggi blob (173px) + padding
                          color: AppColors.background,
                        ),
                      ),
                      // Memanjang jauh ke bawah untuk mengcover scroll panjang
                      Container(
                        width: double.infinity,
                        height: 8000,
                        color: AppColors.background,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // -----------------------------------------------------------------
          // Layer 2b & 3: Area Konten & Settings Gear (Transparan)
          // -----------------------------------------------------------------
          Positioned.fill(
            child: Hero(
              tag: 'content_fade',
              flightShuttleBuilder: buildStaggeredFlightShuttle,
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () => _fetchData(forceRefresh: true),
                    color: AppColors.primary,
                    backgroundColor: Colors.white,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      slivers: [
                // Sediakan sedikit spasi atas agar konten tidak
                // menabrak batas atas (cutOffY) langsung
                SliverPadding(padding: EdgeInsets.only(top: topCutOffY)),

                // Sticky Header "Klass"
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 40,
                  toolbarHeight: 40,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    background: ClipRect(
                      child: Stack(
                        children: [
                          // Background Layer
                          AnimatedBuilder(
                            animation: _scrollController,
                            builder: (context, child) {
                              double offset = _scrollController.hasClients && _scrollController.positions.isNotEmpty
                                  ? _scrollController.positions.first.pixels
                                  : 0;
                              if (offset < 0) offset = 0;
                              return Transform.translate(
                                offset: Offset(0, -offset),
                                child: AnimatedOpacity(
                                  opacity: offset > 20 ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: child,
                                ),
                              );
                            },
                            child: OverflowBox(
                              maxHeight: double.infinity,
                              alignment: Alignment.topCenter,
                              child: Column(
                                children: [
                                  ClipPath(
                                    clipper: Layer2WhiteClipper(
                                      cutOffY: topCutOffY,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      height: 250,
                                      color: AppColors.background.withValues(
                                        alpha: 0.95,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: double.infinity,
                                    height: 8000,
                                    color: AppColors.background.withValues(
                                      alpha: 0.95,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Pinned "Klass" Text
                          Positioned(
                            left: 16,
                            top: topPadding - 2,
                            child: AnimatedBuilder(
                              animation: _scrollController,
                              builder: (context, child) {
                                double offset = _scrollController.hasClients && _scrollController.positions.isNotEmpty
                                    ? _scrollController.positions.first.pixels
                                    : 0;
                                return AnimatedOpacity(
                                  opacity: offset > 20 ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: child,
                                );
                              },
                              child: const Text(
                                'Klass',
                                style: TextStyle(
                                  fontFamily: 'Mona_Sans',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Content body
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero section: Logo + subtitle + prompt
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Transform.translate(
                              offset: const Offset(0, -40),
                              child: const Text(
                                'Klass',
                                style: TextStyle(
                                  fontFamily: 'Mona_Sans',
                                  fontSize: 51,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 0),
                            const Text(
                              'Generate Topik Pembelajaran',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            PromptInputWidget(
                              controller: _promptController,
                              focusNode: _promptFocusNode,
                              onSubmit: (text) async {
                                if (await requireAuth(context)) {
                                  debugPrint('Prompt submitted: $text');
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      // Dynamic Sections
                      ..._buildDynamicSections(),

                      const SizedBox(height: 120), // Space for bottom nav
                    ],
                  ),
                ),
              ],
            ),
                  ),
            
                  // -----------------------------------------------------------------
                  // Layer 3 (Front): Settings Gear Icon (ikut scroll dengan offset)
                  // -----------------------------------------------------------------
                  if (widget.onSettingsTap != null)
                    Positioned(
                      top: 76,
                      right: 36,
                      child: AnimatedBuilder(
                        animation: _scrollController,
                        builder: (context, child) {
                          double offset = 0;
                          if (_scrollController.hasClients && _scrollController.positions.isNotEmpty) {
                            offset = _scrollController.positions.first.pixels;
                            if (offset < 0) offset = 0;
                          }
                          return Transform.translate(
                            offset: Offset(0, -offset),
                            child: child,
                          );
                        },
                        child: GestureDetector(
                          onTap: widget.onSettingsTap,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.settings_rounded,
                              color: AppColors.textMuted,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildFreelancerCard(Map<String, dynamic> freelancer) {
    final avatarSource =
        (freelancer['avatar_url'] ?? freelancer['avatarPath'] ?? '').toString();
    final isNetworkAvatar = avatarSource.startsWith('http');
    final displayName =
        (freelancer['name'] ?? freelancer['creator_id'] ?? 'User').toString();

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return FreelancerDetailsBottomSheet(freelancer: freelancer);
          },
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceCard,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: avatarSource.isNotEmpty
              ? ClipOval(
                  child: Transform.scale(
                    scale: freelancer['scale'] ?? 1.0,
                    alignment: Alignment.center,
                    child: isNetworkAvatar
                        ? Image.network(
                            avatarSource,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildAvatarInitial(displayName),
                          )
                        : Image.asset(
                            avatarSource,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) => _buildAvatarInitial(displayName),
                          ),
                  ),
                )
              : _buildAvatarInitial(displayName),
        ),
        const SizedBox(height: 12),
        Text(
          displayName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildAvatarInitial(String displayName) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(String message, {VoidCallback? onRetry}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: screenWidth - 48, // Matches screen width minus ListView horizontal padding (24+24)
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.red),
          const SizedBox(height: 12),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 100),
              child: SingleChildScrollView(
                child: SelectableText(
                  message,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _copyDebugInfo(message),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Debug Info'),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder(String message, {required IconData icon}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: screenWidth - 48, // Matches screen width minus ListView horizontal padding (24+24)
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: AppColors.border),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
