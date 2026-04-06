import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:klass_app/l10n/generated/app_localizations.dart';
import '../config/app_colors.dart';
import '../services/project_service.dart';
import '../main.dart';

class ProjectSuccessScreen extends StatefulWidget {
  final Map<String, dynamic> project;

  const ProjectSuccessScreen({
    super.key,
    required this.project,
  });

  @override
  State<ProjectSuccessScreen> createState() => _ProjectSuccessScreenState();
}

class _ProjectSuccessScreenState extends State<ProjectSuccessScreen> with SingleTickerProviderStateMixin {
  final ProjectService _projectService = ProjectService();
  late final AnimationController _contentController;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    
    _scrollController.addListener(_onScroll);

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _contentFade = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    ));

    // Wait for the PageRouteBuilder fade-in (400ms) to complete,
    // then start the content slide-up animation.
    Future.delayed(const Duration(milliseconds: 420), () {
      if (mounted) _contentController.forward();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Gunakan threshold yang sedikit lebih besar untuk stabilitas
    final bool isScrolled = _scrollController.offset > 20;
    if (isScrolled != _isScrolled) {
      setState(() {
        _isScrolled = isScrolled;
      });
    }
  }

  void _handleGoToWorkspace() {
    // 1. Sinkronisasi State: Tambahkan proyek ke service
    _projectService.addProject(widget.project);

    // 2. Navigasi: Kembali ke MainShell dan pindah ke tab Workspace (indeks 2)
    Navigator.of(context).popUntil((route) => route.isFirst);

    // Gunakan GlobalKey untuk mengubah tab di MainShell
    KlassApp.mainShellKey.currentState?.setTabIndex(2);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final List<dynamic> modules = widget.project['modules'] ?? [];
    final double topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Atmospheric Decorations ───────────────────────────────────
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // ── Main Scrollable Content ───────────────────────────────────
          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: topPadding + 100),

                // ── Checklist Icon ──
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: -10,
                      right: -10,
                      child: RotationTransition(
                        turns: const AlwaysStoppedAnimation(-12 / 360),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -10,
                      left: -15,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Transform.rotate(
                            angle: (1.0 - value) * 0.1,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 80,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                // ── Slide-up Content ──
                SlideTransition(
                  position: _contentSlide,
                  child: FadeTransition(
                    opacity: _contentFade,
                    child: Column(
                      children: [
                        Text(
                          localizations.projectSuccessTitle,
                          style: TextStyle(
                            fontFamily: 'Mona_Sans',
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          localizations.projectSuccessDescription(
                            (widget.project['title'] ?? localizations.homeUntitled).toString(),
                          ),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 48),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.5),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          localizations.projectSuccessProjectTitleLabel,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 2,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          widget.project['title'] ??
                                              localizations.projectConfirmationFallbackTitle,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      localizations.projectSuccessNewBadge,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Container(
                                height: 1,
                                color: AppColors.border.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          localizations.projectSuccessModulesLabel,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 2,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                                Icons.auto_stories_rounded,
                                                color: AppColors.primary,
                                                size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              localizations.projectSuccessUnits(modules.length),
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          localizations.projectSuccessAccessLabel,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 2,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.group_rounded,
                                                color: AppColors.primary,
                                                size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              localizations.navWorkspace,
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 48),

                        ElevatedButton(
                          onPressed: _handleGoToWorkspace,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 64),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 8,
                            shadowColor:
                                AppColors.primary.withValues(alpha: 0.3),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                localizations.projectSuccessGoToWorkspace,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 12),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(double.infinity, 64),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            localizations.projectSuccessExploreMoreProjects,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),

                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Fixed Header Overlay ──────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: Stack(
                children: [
                  // Latar belakang blur & warna yang beranimasi serempak
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: _isScrolled ? 1.0 : 0.0),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      if (value <= 0) return const SizedBox.shrink();
                      return BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: value * 10,
                          sigmaY: value * 10,
                        ),
                        child: Container(
                          height: topPadding + 72,
                          color: AppColors.surface.withValues(alpha: value * 0.8),
                        ),
                      );
                    },
                  ),
                  // Konten Header (selalu tajam, tidak ikut blur)
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            localizations.appTitle,
                            style: TextStyle(
                              fontFamily: 'Mona_Sans',
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              color: AppColors.primary,
                              letterSpacing: -1,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.textMuted,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
