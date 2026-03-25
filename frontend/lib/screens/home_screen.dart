import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../widgets/prompt_input_widget.dart';
import '../widgets/project_suggestion_card.dart';
import '../widgets/bleeding_horizontal_list.dart';
import '../widgets/layer2_white_clipper.dart';

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

  // Dummy data — mereplikasi projects dari Next.js
  final List<Map<String, String>> projects = [
    {
      'title': 'Modern History of Indonesia',
      'author': 'By Antigravity',
      'ratio': 'ppt',
    },
    {
      'title': 'Benefits of Healthy Eating',
      'author': 'By Antigravity',
      'ratio': 'infographic',
    },
    {
      'title': 'Mathematics Quiz',
      'author': 'By Antigravity',
      'ratio': 'square',
    },
  ];

  final List<Map<String, dynamic>> freelancers = [
    {'name': 'Agus S', 'role': 'Math Tutor', 'rate': 45},
    {'name': 'Ani A', 'role': 'Designer', 'rate': 35},
    {'name': 'Budi O', 'role': 'Developer', 'rate': 55},
    {'name': 'Susi', 'role': 'English', 'rate': 30},
  ];

  @override
  void dispose() {
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
                      child: Container(
                        width: 160,
                        height: 140,
                        decoration: const BoxDecoration(
                          color: AppColors.brown,
                          borderRadius: BorderRadius.all(Radius.elliptical(80, 70)),
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
              child: Column(
                 children: [
                   ClipPath(
                     clipper: Layer2WhiteClipper(cutOffY: topCutOffY),
                     child: Container(
                       width: double.infinity,
                       height: 250, // Cukup untuk mencakup tinggi blob (173px) + padding
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

          // -----------------------------------------------------------------
          // Layer 2b (Middle-Front): Area Konten (Transparan)
          // -----------------------------------------------------------------
          Positioned.fill(
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
                                    double offset = _scrollController.hasClients ? _scrollController.offset : 0;
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
                                          clipper: Layer2WhiteClipper(cutOffY: topCutOffY),
                                          child: Container(
                                            width: double.infinity,
                                            height: 250,
                                            color: AppColors.background.withValues(alpha: 0.95),
                                          ),
                                        ),
                                        Container(
                                          width: double.infinity,
                                          height: 8000,
                                          color: AppColors.background.withValues(alpha: 0.95),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Pinned "Klass" Text
                                Positioned(
                                  left: 16,
                                  top: topPadding - 18,
                                  child: AnimatedBuilder(
                                    animation: _scrollController,
                                    builder: (context, child) {
                                      double offset = _scrollController.hasClients ? _scrollController.offset : 0;
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

          // -----------------------------------------------------------------
          // Layer 3 (Front): Settings Gear Icon diletakkan secara terpisah
          // -----------------------------------------------------------------
          if (widget.onSettingsTap != null)
             Positioned(
               top: 62,
               right: 29, 
               child: GestureDetector(
                 onTap: widget.onSettingsTap,
                 child: Container(
                   width: 50,
                   height: 50,
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
                     size: 24,
                   ),
                 ),
               ),
             ),
        ],
      ),
    );
  }

  Widget _buildFreelancerCard(Map<String, dynamic> freelancer) {
    return Column(
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
          child: Center(
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
    );
  }
}
