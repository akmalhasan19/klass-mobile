// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Klass';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navWorkspace => 'Workspace';

  @override
  String get navProfile => 'Profile';

  @override
  String get navJobs => 'Jobs';

  @override
  String get navPortfolio => 'Portfolio';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageBahasaIndonesia => 'Bahasa Indonesia';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionAiPreferences => 'AI Preferences';

  @override
  String get settingsCreativityLevel => 'CREATIVITY LEVEL';

  @override
  String get settingsCreativityPrecise => 'Precise';

  @override
  String get settingsCreativityBalanced => 'Balanced';

  @override
  String get settingsCreativityCreative => 'Creative';

  @override
  String get settingsLearningStyles => 'LEARNING STYLES';

  @override
  String get settingsLearningStyleVisual => 'Visual';

  @override
  String get settingsLearningStyleHandsOn => 'Hands-on';

  @override
  String get settingsLearningStyleReading => 'Reading';

  @override
  String get settingsDefaultProjectComplexity => 'DEFAULT PROJECT COMPLEXITY';

  @override
  String get settingsComplexityBeginner => 'Beginner';

  @override
  String get settingsComplexityIntermediate => 'Intermediate';

  @override
  String get settingsComplexityAdvanced => 'Advanced';

  @override
  String get settingsSectionInterfaceTheme => 'Interface & Theme';

  @override
  String get settingsThemeModeTitle => 'Theme Mode';

  @override
  String get settingsThemeModeSubtitle => 'Switch between light and dark';

  @override
  String get settingsLanguageLabel => 'System Language';

  @override
  String get settingsSectionWorkspaceData => 'Workspace & Data';

  @override
  String get settingsAutoSaveProjectsTitle => 'Auto-save projects';

  @override
  String get settingsAutoSaveProjectsSubtitle => 'Sync changes in real-time';

  @override
  String get settingsClearHistoryTitle => 'Clear history';

  @override
  String get settingsClearHistorySubtitle => 'Wipe all generation logs';

  @override
  String get settingsClearHistoryAction => 'CLEAR';

  @override
  String get settingsCreatorToolsTitle => 'Creator Tools';

  @override
  String get settingsCreatorToolsDescription =>
      'Access special tools to create high-quality educational content.';

  @override
  String get settingsCreatorDashboardButton => 'Open Creator Dashboard';

  @override
  String get settingsCreatorDashboardFeatureTitle => 'Creator Dashboard';

  @override
  String get settingsCreatorDashboardFeatureDescription =>
      'We are building a powerful dashboard for creators to manage their educational content, track student progress, and analyze engagement.';

  @override
  String get settingsCreatorDashboardFeatureName => 'Content Analytics';

  @override
  String get settingsCreatorDashboardFeatureHelper =>
      'Deep insights into how students interact with your materials.';

  @override
  String get settingsRequestClubFeatureTitle => 'Request a Club';

  @override
  String get settingsRequestClubFeatureDescription =>
      'Clubs are coming to Klass! You will soon be able to create and join communities focused on specific subjects and interests.';

  @override
  String get settingsRequestClubFeatureName => 'Club Communities';

  @override
  String get settingsRequestClubFeatureHelper =>
      'Collaborate with other students and teachers in specialized groups.';

  @override
  String get settingsRequestClubCardTitle => 'Request New Club';

  @override
  String get settingsRequestClubCardSubtitle =>
      'Request a new club for your community';

  @override
  String settingsVersionLabel(Object version) {
    return 'KLASS VERSION $version';
  }

  @override
  String get settingsLogOut => 'Log Out';

  @override
  String get featureComingSoonDefaultTitle => 'A New Chapter for Your Library';

  @override
  String get featureComingSoonDefaultDescription =>
      'We’re busy building this feature for you. It’ll be ready in a future update! Our curators are currently indexing new collections to enhance your experience.';

  @override
  String get featureComingSoonDefaultFeatureName => 'Enhanced Archiving';

  @override
  String get featureComingSoonDefaultFeatureDescription =>
      'Intelligent cross-referencing for your sources.';

  @override
  String get featureComingSoonHeader => 'Upcoming Feature';

  @override
  String get featureComingSoonBadge => 'COMING SOON';

  @override
  String get featureComingSoonDismiss => 'Got it!';

  @override
  String get promptInputHint => 'Type a topic you want to learn...';

  @override
  String get animatedSearchHint => 'Search for teachers, topics...';

  @override
  String get projectDetailsFallbackTitle => 'Review Project';

  @override
  String get projectDetailsOverviewTitle => 'Overview';

  @override
  String get projectDetailsNoDescription => 'No description provided.';

  @override
  String get projectDetailsRecreate => 'Recreate';

  @override
  String get projectDetailsUseAsIs => 'Use as it is';

  @override
  String get projectConfirmationTitle => 'Project Confirmation';

  @override
  String get projectConfirmationTemplateBadge => 'TEMPLATE';

  @override
  String get projectConfirmationCreatedBy => 'Created by Education Team';

  @override
  String get projectConfirmationFallbackTitle => 'Botany 101';

  @override
  String get projectConfirmationDescription =>
      'Review the modules included in this project before adding it to your workspace. This curated sequence is designed for optimal learning outcomes.';

  @override
  String get projectConfirmationModulesSlides => 'Project Modules (Slides)';

  @override
  String get projectConfirmationModulesPoints => 'Project Modules (Points)';

  @override
  String get projectConfirmationModulesQuiz => 'Project Modules (Quiz)';

  @override
  String projectConfirmationModulesTotal(int count) {
    return '$count Modules Total';
  }

  @override
  String get projectConfirmationWorkspaceSlotPrefix =>
      'Adding this project will use ';

  @override
  String get projectConfirmationWorkspaceSlotHighlight => '1 workspace slot';

  @override
  String get projectConfirmationWorkspaceSlotSuffix =>
      '. You can edit these modules later in your Project Dashboard.';

  @override
  String get projectConfirmationConfirm => 'Confirm & Add to Workspace';

  @override
  String get projectConfirmationCancel => 'Cancel';

  @override
  String get freelancerDetailsUnknown => 'Unknown';

  @override
  String get freelancerDetailsPerHour => '/hr';

  @override
  String get freelancerDetailsProjects => 'PROJECTS';

  @override
  String get freelancerDetailsRating => 'RATING';

  @override
  String get freelancerDetailsResponse => 'RESPONSE';

  @override
  String freelancerDetailsHire(Object name) {
    return 'Hire $name';
  }
}
