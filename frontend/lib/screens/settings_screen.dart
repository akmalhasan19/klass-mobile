import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:klass_app/l10n/generated/app_localizations.dart';
import '../config/app_colors.dart';
import '../widgets/top_right_accent.dart';
import '../widgets/layer2_white_clipper.dart';
import '../config/animations.dart';
import '../widgets/feature_coming_soon.dart';
import '../services/auth_service.dart';
import '../services/locale_preferences_service.dart';
import '../main.dart';

/// Settings Screen — mereplikasi halaman Settings dari Klass Next.js.
/// Fitur: AI Preferences, Interface & Theme, Workspace & Data,
/// Creator Tools (BROWN), Request New Club (BROWN), Logout.
class SettingsScreen extends StatefulWidget {
  static const Key screenKey = Key('settings_screen');
  static const Key languageControlKey = Key('settings_language_control');
  static const Key languageCurrentValueKey = Key('settings_language_current_value');
  static const Key languageEnglishOptionKey = Key('settings_language_option_en');
  static const Key languageBahasaIndonesiaOptionKey = Key('settings_language_option_id');

  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _creativity = 2;
  String _learningStyle = 'visual';
  String _complexity = 'intermediate';
  bool _isDarkMode = true;
  bool _autoSave = true;
  bool _isUpdatingLocale = false;
  // ignore: unused_field
  String? _userRole;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final role = await _authService.getUserRole();
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }
  }

  Future<void> _handleLocaleSelection(Locale locale) async {
    if (_isUpdatingLocale) {
      return;
    }

    final matchedLocale = LocalePreferencesService.matchSupportedLocale(
      locale,
      supportedLocales: KlassApp.supportedLocales,
    );
    if (matchedLocale == null) {
      return;
    }

    final currentLocale = _resolveActiveLocale(context);
    if (LocalePreferencesService.sameLocale(currentLocale, matchedLocale)) {
      return;
    }

    setState(() {
      _isUpdatingLocale = true;
    });

    try {
      await KlassApp.of(context).updateLocale(matchedLocale);
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingLocale = false;
        });
      }
    }
  }

  Locale _resolveActiveLocale(BuildContext context) {
    return LocalePreferencesService.matchSupportedLocale(
          Localizations.localeOf(context),
          supportedLocales: KlassApp.supportedLocales,
        ) ??
        KlassApp.supportedLocales.first;
  }

  String _languageLabelForLocale(
    Locale locale,
    AppLocalizations? localizations,
  ) {
    return locale.languageCode == 'id'
        ? localizations?.languageBahasaIndonesia ?? 'Bahasa Indonesia'
        : localizations?.languageEnglish ?? 'English';
  }

  String _learningStyleLabel(String value, AppLocalizations? localizations) {
    switch (value) {
      case 'hands_on':
        return localizations?.settingsLearningStyleHandsOn ?? 'Hands-on';
      case 'reading':
        return localizations?.settingsLearningStyleReading ?? 'Reading';
      case 'visual':
      default:
        return localizations?.settingsLearningStyleVisual ?? 'Visual';
    }
  }

  String _complexityLabel(String value, AppLocalizations? localizations) {
    switch (value) {
      case 'beginner':
        return localizations?.settingsComplexityBeginner ?? 'Beginner';
      case 'advanced':
        return localizations?.settingsComplexityAdvanced ?? 'Advanced';
      case 'intermediate':
      default:
        return localizations?.settingsComplexityIntermediate ?? 'Intermediate';
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final localizations = AppLocalizations.of(context);
    final activeLocale = _resolveActiveLocale(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        key: SettingsScreen.screenKey,
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Top right accent shape (Layer 1, will be covered by Layer 2)
            const TopRightAccent(),

            // Layer 2 background expanding from Hero
            Positioned.fill(
              child: Hero(
                tag: 'layer2_bg',
                flightShuttleBuilder: (
                  BuildContext flightContext,
                  Animation<double> animation,
                  HeroFlightDirection flightDirection,
                  BuildContext fromHeroContext,
                  BuildContext toHeroContext,
                ) {
                  final topCutOffY = topPadding > 0 ? topPadding + 8.0 : 24.0;
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
                  child: ClipPath(
                    clipper: Layer2WhiteClipper(cutOffY: 0.0),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: AppColors.background,
                    ),
                  ),
                ),
              ),
            ),

            // Main content
            Positioned.fill(
              child: Hero(
                tag: 'content_fade',
                flightShuttleBuilder: buildStaggeredFlightShuttle,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: topPadding + 12),
                  // Header
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            width: 48,
                            height: 48,
                            color: Colors.transparent,
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              size: 20,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          localizations?.settingsTitle ?? 'Settings',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // AI Preferences Section
                  _buildSectionHeader(
                    icon: Icons.psychology_rounded,
                    title: localizations?.settingsSectionAiPreferences ?? 'AI Preferences',
                  ),
                  const SizedBox(height: 12),

                  // Creativity Slider
                  _buildSettingsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel(localizations?.settingsCreativityLevel ?? 'CREATIVITY LEVEL'),
                        const SizedBox(height: 16),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: AppColors.primary,
                            inactiveTrackColor: AppColors.border,
                            thumbColor: AppColors.primary,
                            overlayColor:
                                AppColors.primary.withValues(alpha: 0.15),
                            trackHeight: 6,
                          ),
                          child: Slider(
                            value: _creativity,
                            min: 1,
                            max: 3,
                            divisions: 2,
                            onChanged: (v) =>
                                setState(() => _creativity = v),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _creativityLabel(localizations?.settingsCreativityPrecise ?? 'Precise', _creativity.round() == 1),
                            _creativityLabel(localizations?.settingsCreativityBalanced ?? 'Balanced', _creativity.round() == 2),
                            _creativityLabel(localizations?.settingsCreativityCreative ?? 'Creative', _creativity.round() == 3),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Learning Styles
                  _buildSettingsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel(localizations?.settingsLearningStyles ?? 'LEARNING STYLES'),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: ['visual', 'hands_on', 'reading']
                              .map((style) => _buildChip(
                                  label: _learningStyleLabel(style, localizations),
                                  isActive: _learningStyle == style,
                                      onTap: () =>
                                          setState(() => _learningStyle = style),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Project Complexity
                  _buildSettingsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel(localizations?.settingsDefaultProjectComplexity ?? 'DEFAULT PROJECT COMPLEXITY'),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: ['beginner', 'intermediate', 'advanced']
                                .map((lvl) => _buildComplexityButton(lvl))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Interface & Theme Section
                  _buildSectionHeader(
                    icon: Icons.palette_rounded,
                    title: localizations?.settingsSectionInterfaceTheme ?? 'Interface & Theme',
                  ),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    child: Column(
                      children: [
                        _buildToggleRow(
                          icon: Icons.dark_mode_rounded,
                          title: localizations?.settingsThemeModeTitle ?? 'Theme Mode',
                          subtitle: localizations?.settingsThemeModeSubtitle ?? 'Switch between light and dark',
                          value: _isDarkMode,
                          onChanged: (v) =>
                              setState(() => _isDarkMode = v),
                        ),
                        Divider(
                            color: AppColors.border.withValues(alpha: 0.5),
                            height: 1),
                        _buildLanguageSelector(
                          localizations: localizations,
                          activeLocale: activeLocale,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Workspace & Data Section
                  _buildSectionHeader(
                    icon: Icons.storage_rounded,
                    title: localizations?.settingsSectionWorkspaceData ?? 'Workspace & Data',
                  ),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    child: Column(
                      children: [
                        _buildToggleRow(
                          icon: Icons.save_rounded,
                          title: localizations?.settingsAutoSaveProjectsTitle ?? 'Auto-save projects',
                          subtitle: localizations?.settingsAutoSaveProjectsSubtitle ?? 'Sync changes in real-time',
                          value: _autoSave,
                          onChanged: (v) =>
                              setState(() => _autoSave = v),
                        ),
                        Divider(
                            color: AppColors.border.withValues(alpha: 0.5),
                            height: 1),
                        _buildActionRow(
                          icon: Icons.history_rounded,
                          title: localizations?.settingsClearHistoryTitle ?? 'Clear history',
                          subtitle: localizations?.settingsClearHistorySubtitle ?? 'Wipe all generation logs',
                          actionLabel: localizations?.settingsClearHistoryAction ?? 'CLEAR',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ═══════════════════════════════════════════════
                  // CREATOR TOOLS & REQUEST NEW CLUB
                  // ═══════════════════════════════════════════════
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GestureDetector(
                      onTap: () => FeatureComingSoon.show(
                        context,
                        title: localizations?.settingsCreatorToolsTitle,
                        description: localizations?.settingsCreatorDashboardFeatureDescription,
                        featureName: localizations?.settingsCreatorDashboardFeatureTitle,
                        featureDescription: localizations?.settingsCreatorDashboardFeatureDescription,
                        icon: Icons.dashboard_customize_rounded,
                        previewIcon: Icons.dashboard_rounded,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.brown,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brown.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.dashboard_customize_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations?.settingsCreatorToolsTitle ?? 'Creator Tools',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    localizations?.settingsCreatorDashboardButton ?? 'Open Creator Dashboard',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GestureDetector(
                      onTap: () => FeatureComingSoon.show(
                        context,
                        title: localizations?.settingsRequestClubFeatureTitle,
                        description: localizations?.settingsRequestClubFeatureDescription,
                        featureName: localizations?.settingsRequestClubFeatureName,
                        featureDescription: localizations?.settingsRequestClubFeatureHelper,
                        icon: Icons.group_add_rounded,
                        previewIcon: Icons.groups_rounded,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.brown,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brown.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.group_add_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations?.settingsRequestClubCardTitle ?? 'Request New Club',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    localizations?.settingsRequestClubCardSubtitle ?? 'Request a new club for your community',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Logout
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {}, // Handled in real app
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.logout_rounded),
                        label: Text(
                          localizations?.settingsLogOut ?? 'Logout',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Version
                  Center(
                    child: Text(
                      localizations?.settingsVersionLabel('1.0.0') ?? 'KLASS VERSION 1.0.0',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textMuted,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            ),
            ),

            // Bottom Nav Dummy for Hero fade
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Hero(
                tag: 'bottom_nav_fade',
                child: Container(height: 80, color: Colors.transparent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══ Helper Widgets ═══

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 2,
      ),
    );
  }

  Widget _creativityLabel(String label, bool isActive) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: isActive ? AppColors.primary : AppColors.textMuted,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildChip({
    Key? key,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector({
    required AppLocalizations? localizations,
    required Locale activeLocale,
  }) {
    final currentLanguageLabel = _languageLabelForLocale(
      activeLocale,
      localizations,
    );

    return Padding(
      key: SettingsScreen.languageControlKey,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  Icons.language_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations?.settingsLanguageLabel ?? 'System Language',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentLanguageLabel,
                      key: SettingsScreen.languageCurrentValueKey,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isUpdatingLocale ? 1 : 0,
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 54),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildChip(
                  key: SettingsScreen.languageEnglishOptionKey,
                  label: localizations?.languageEnglish ?? 'English',
                  isActive: activeLocale.languageCode == 'en',
                  onTap: () => _handleLocaleSelection(const Locale('en')),
                ),
                _buildChip(
                  key: SettingsScreen.languageBahasaIndonesiaOptionKey,
                  label: localizations?.languageBahasaIndonesia ?? 'Bahasa Indonesia',
                  isActive: activeLocale.languageCode == 'id',
                  onTap: () => _handleLocaleSelection(const Locale('id')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplexityButton(String level) {
    final localizations = AppLocalizations.of(context);
    final isActive = _complexity == level;
    return GestureDetector(
      onTap: () => setState(() => _complexity = level),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            _complexityLabel(level, localizations),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 20, color: AppColors.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textMuted,
                    )),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 24,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: value ? AppColors.primary : AppColors.border,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 20, color: AppColors.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textMuted,
                    )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
