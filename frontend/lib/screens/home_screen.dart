import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../widgets/prompt_input_widget.dart';
import '../widgets/project_suggestion_card.dart';
import '../widgets/bleeding_horizontal_list.dart';
import '../widgets/layer2_white_clipper.dart';
import '../widgets/project_details_bottom_sheet.dart';
import '../widgets/freelancer_details_bottom_sheet.dart';

/// Home Screen — mereplikasi halaman utama Klass.
/// Fitur: Sticky header "Klass", prompt input, project suggestions,
/// project recommendations (bleed), top freelancers (bleed).
class HomeScreen extends StatefulWidget {
  final VoidCallback? onSettingsTap;

  const HomeScreen({super.key, this.onSettingsTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _promptController = TextEditingController();

  // Dummy data — mereplikasi projects dari Next.js
  final List<Map<String, dynamic>> projects = [
    {
      'title': 'Modern History of Indonesia',
      'author': 'By Antigravity',
      'ratio': 'ppt',
      'imagePath': 'assets/images/ppt_design_3.jpg',
      'description':
          'Explore the journey of Indonesia from the colonial era to the modern age. This project covers key historical events, the struggle for independence, and the development of the nation. Perfect for students and history enthusiasts looking to understand the roots of contemporary Indonesia.',
      'tags': ['History', 'Indonesia', 'Education'],
      'type': 'PPT',
      'modules': [
        {'title': 'Masa Kolonial Belanda', 'detail': '2 Slides'},
        {'title': 'Perjuangan Kemerdekaan', 'detail': '3 Slides'},
        {'title': 'Era Orde Lama & Baru', 'detail': '2 Slides'},
        {'title': 'Indonesia Modern', 'detail': '1 Slide'}
      ],
    },
    {
      'title': 'Benefits of Healthy Eating',
      'author': 'By Antigravity',
      'ratio': 'infographic',
      'imagePath': 'assets/images/infographic_preview_health_1773981088610.png',
      'description':
          'Discover how nutrition impacts your daily life and long-term health. This infographic project breaks down complex dietary concepts into easy-to-understand visuals, covering vitamins, minerals, and the importance of a balanced diet. Great for health campaigns and personal awareness.',
      'tags': ['Health', 'Nutrition', 'Design'],
      'type': 'Infographic',
      'modules': [
        {'title': 'Pentingnya Makronutrien', 'detail': 'Karbo, Protein, Lemak'},
        {'title': 'Mikronutrien Esensial', 'detail': 'Vitamin & Mineral'},
        {'title': 'Dampak Jangka Panjang', 'detail': 'Pencegahan Penyakit'}
      ],
    },
    {
      'title': 'Mathematics Quiz',
      'author': 'By Antigravity',
      'ratio': 'square',
      'imagePath': 'assets/images/square_preview_math_1773981103817.png',
      'description':
          'A fun and interactive way to test your mathematical skills. Covering algebra, geometry, and basic arithmetic, this project is designed to challenge students and make learning math enjoyable through gamification and clear visual feedback.',
      'tags': ['Math', 'Quiz', 'Learning'],
      'type': 'Quiz',
      'modules': [
        {'title': 'Aljabar Dasar', 'detail': '5 Pertanyaan'},
        {'title': 'Geometri', 'detail': '4 Pertanyaan'},
        {'title': 'Aritmatika Lanjut', 'detail': '6 Pertanyaan'}
      ],
    },
  ];

  final List<Map<String, dynamic>> freelancers = [
    {
      'name': 'Agus S',
      'avatarPath': 'assets/avatars/agus.png',
      'role': 'Advanced Mathematics Tutor',
      'rate': 45,
      'skills': ['Calculus', 'SAT Prep', 'Algebra', 'Physics'],
      'projects': 42,
      'rating': 4.9,
      'responseTime': '< 1h',
      'verified': true,
      'scale': 1.1,
    },
    {
      'name': 'Ani A',
      'avatarPath': 'assets/avatars/ani.png',
      'role': 'Creative Graphic Designer',
      'rate': 35,
      'skills': ['UI/UX', 'Illustration', 'Branding', 'Figma'],
      'projects': 28,
      'rating': 4.8,
      'responseTime': '< 2h',
      'verified': true,
      'scale': 1.1,
    },
    {
      'name': 'Budi O',
      'avatarPath': 'assets/avatars/budi.png',
      'role': 'Fullstack Web Developer',
      'rate': 55,
      'skills': ['Next.js', 'TypeScript', 'Node.js', 'Tailwind'],
      'projects': 56,
      'rating': 5.0,
      'responseTime': '< 30m',
      'verified': true,
      'scale': 1.3,
    },
    {
      'name': 'Susi',
      'avatarPath': 'assets/avatars/susi.png',
      'role': 'English Language Specialist',
      'rate': 30,
      'skills': ['IELTS', 'TOEFL', 'Business English', 'Writing'],
      'projects': 34,
      'rating': 4.7,
      'responseTime': '< 3h',
      'verified': false,
      'scale': 1.2,
    },
  ];

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
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
                if (_scrollController.hasClients) {
                  offset = _scrollController.offset;
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
          // Layer 2b (Middle-Front): Area Konten (Transparan)
          // -----------------------------------------------------------------
          Positioned.fill(
            child: AnimatedBuilder(
              animation: ModalRoute.of(context)?.secondaryAnimation ?? const AlwaysStoppedAnimation(0.0),
              builder: (context, child) {
                final val = ModalRoute.of(context)?.secondaryAnimation?.value ?? 0.0;
                final opacity = val < 0.5 ? 1.0 - (val * 2) : 0.0;
                return Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: child,
                );
              },
              child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
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
                              double offset = _scrollController.hasClients
                                  ? _scrollController.offset
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
                                double offset = _scrollController.hasClients
                                    ? _scrollController.offset
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
                              onSubmit: (text) {
                                debugPrint('Prompt submitted: $text');
                              },
                            ),
                          ],
                        ),
                      ),

                      // Project Suggestions
                      BleedingHorizontalList(
                        title: 'Project Suggestions',
                        height: 260,
                        children: projects.map((p) {
                          return ProjectSuggestionCard(
                            title: p['title']!,
                            author: p['author']!,
                            ratio: p['ratio']!,
                            imagePath: p['imagePath'],
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) {
                                  return ProjectDetailsBottomSheet(
                                    project: p,
                                    onRecreate: (description) {
                                      _promptController.text = description;
                                    },
                                  );
                                },
                              );
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),

                      // Top Freelancers
                      BleedingHorizontalList(
                        title: 'Top Freelancers',
                        height: 140,
                        itemSpacing: 25,
                        children: freelancers.map((f) {
                          return _buildFreelancerCard(f);
                        }).toList(),
                      ),
                      const SizedBox(height: 120), // Space for bottom nav
                    ],
                  ),
                ),
              ],
            ),
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
                animation: ModalRoute.of(context)?.secondaryAnimation ?? const AlwaysStoppedAnimation(0.0),
                builder: (context, child) {
                  final val = ModalRoute.of(context)?.secondaryAnimation?.value ?? 0.0;
                  final opacity = val < 0.5 ? 1.0 - (val * 2) : 0.0;
                  return Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: child,
                  );
                },
                child: AnimatedBuilder(
                  animation: _scrollController,
                  builder: (context, child) {
                    double offset = 0;
                    if (_scrollController.hasClients) {
                      offset = _scrollController.offset;
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
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildFreelancerCard(Map<String, dynamic> freelancer) {
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
          child: freelancer['avatarPath'] != null
              ? ClipOval(
                  child: Transform.scale(
                    scale: freelancer['scale'] ?? 1.0,
                    alignment: Alignment.center,
                    child: Image.asset(
                      freelancer['avatarPath'],
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    freelancer['name']![0],
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Text(
          freelancer['name']!,
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
}
