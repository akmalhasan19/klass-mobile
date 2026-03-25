import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../widgets/prompt_input_widget.dart';
import '../widgets/project_suggestion_card.dart';
import '../widgets/bleeding_horizontal_list.dart';
import '../widgets/top_right_accent.dart';

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
  double _scrollOffset = 0;

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
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
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
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Stack(
        children: [
          // Background layers yang extend di belakang status bar
          _buildBackgroundLayers(topPadding),

          // Main scrollable content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Sticky Header "Klass"
              SliverAppBar(
                pinned: true,
                expandedHeight: 80 + topPadding,
                toolbarHeight: 60,
                backgroundColor: _scrollOffset > 20
                    ? AppColors.background.withValues(alpha: 0.95)
                    : Colors.transparent,
                surfaceTintColor: Colors.transparent,
                automaticallyImplyLeading: false,
                title: AnimatedOpacity(
                  opacity: _scrollOffset > 20 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Text(
                    'Klass',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(color: Colors.transparent),
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
                          const Text(
                            'Klass',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 51,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
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

                    // Project Suggestions (horizontal scroll, bleed effect)
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

                    // Top Freelancers (bleed effect)
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

          // Top right accent shape (hijau + coklat + gear)
          TopRightAccent(onSettingsTap: widget.onSettingsTap),
        ],
      ),
    );
  }

  Widget _buildBackgroundLayers(double topPadding) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          // Layer 1: Background hitam utama
          color: AppColors.background,
        ),
        child: Stack(
          children: [
            // Layer 2: Subtle gradient diagonal
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.06),
                      Colors.transparent,
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
