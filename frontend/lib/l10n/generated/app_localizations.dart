import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Klass'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get navWorkspace;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navJobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get navJobs;

  /// No description provided for @navPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Portfolio'**
  String get navPortfolio;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageBahasaIndonesia.
  ///
  /// In en, this message translates to:
  /// **'Bahasa Indonesia'**
  String get languageBahasaIndonesia;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionAiPreferences.
  ///
  /// In en, this message translates to:
  /// **'AI Preferences'**
  String get settingsSectionAiPreferences;

  /// No description provided for @settingsCreativityLevel.
  ///
  /// In en, this message translates to:
  /// **'CREATIVITY LEVEL'**
  String get settingsCreativityLevel;

  /// No description provided for @settingsCreativityPrecise.
  ///
  /// In en, this message translates to:
  /// **'Precise'**
  String get settingsCreativityPrecise;

  /// No description provided for @settingsCreativityBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get settingsCreativityBalanced;

  /// No description provided for @settingsCreativityCreative.
  ///
  /// In en, this message translates to:
  /// **'Creative'**
  String get settingsCreativityCreative;

  /// No description provided for @settingsLearningStyles.
  ///
  /// In en, this message translates to:
  /// **'LEARNING STYLES'**
  String get settingsLearningStyles;

  /// No description provided for @settingsLearningStyleVisual.
  ///
  /// In en, this message translates to:
  /// **'Visual'**
  String get settingsLearningStyleVisual;

  /// No description provided for @settingsLearningStyleHandsOn.
  ///
  /// In en, this message translates to:
  /// **'Hands-on'**
  String get settingsLearningStyleHandsOn;

  /// No description provided for @settingsLearningStyleReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get settingsLearningStyleReading;

  /// No description provided for @settingsDefaultProjectComplexity.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT PROJECT COMPLEXITY'**
  String get settingsDefaultProjectComplexity;

  /// No description provided for @settingsComplexityBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get settingsComplexityBeginner;

  /// No description provided for @settingsComplexityIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get settingsComplexityIntermediate;

  /// No description provided for @settingsComplexityAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsComplexityAdvanced;

  /// No description provided for @settingsSectionInterfaceTheme.
  ///
  /// In en, this message translates to:
  /// **'Interface & Theme'**
  String get settingsSectionInterfaceTheme;

  /// No description provided for @settingsThemeModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get settingsThemeModeTitle;

  /// No description provided for @settingsThemeModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch between light and dark'**
  String get settingsThemeModeSubtitle;

  /// No description provided for @settingsLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'System Language'**
  String get settingsLanguageLabel;

  /// No description provided for @settingsSectionWorkspaceData.
  ///
  /// In en, this message translates to:
  /// **'Workspace & Data'**
  String get settingsSectionWorkspaceData;

  /// No description provided for @settingsAutoSaveProjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-save projects'**
  String get settingsAutoSaveProjectsTitle;

  /// No description provided for @settingsAutoSaveProjectsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync changes in real-time'**
  String get settingsAutoSaveProjectsSubtitle;

  /// No description provided for @settingsClearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get settingsClearHistoryTitle;

  /// No description provided for @settingsClearHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Wipe all generation logs'**
  String get settingsClearHistorySubtitle;

  /// No description provided for @settingsClearHistoryAction.
  ///
  /// In en, this message translates to:
  /// **'CLEAR'**
  String get settingsClearHistoryAction;

  /// No description provided for @settingsCreatorToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Creator Tools'**
  String get settingsCreatorToolsTitle;

  /// No description provided for @settingsCreatorToolsDescription.
  ///
  /// In en, this message translates to:
  /// **'Access special tools to create high-quality educational content.'**
  String get settingsCreatorToolsDescription;

  /// No description provided for @settingsCreatorDashboardButton.
  ///
  /// In en, this message translates to:
  /// **'Open Creator Dashboard'**
  String get settingsCreatorDashboardButton;

  /// No description provided for @settingsCreatorDashboardFeatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Creator Dashboard'**
  String get settingsCreatorDashboardFeatureTitle;

  /// No description provided for @settingsCreatorDashboardFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'We are building a powerful dashboard for creators to manage their educational content, track student progress, and analyze engagement.'**
  String get settingsCreatorDashboardFeatureDescription;

  /// No description provided for @settingsCreatorDashboardFeatureName.
  ///
  /// In en, this message translates to:
  /// **'Content Analytics'**
  String get settingsCreatorDashboardFeatureName;

  /// No description provided for @settingsCreatorDashboardFeatureHelper.
  ///
  /// In en, this message translates to:
  /// **'Deep insights into how students interact with your materials.'**
  String get settingsCreatorDashboardFeatureHelper;

  /// No description provided for @settingsRequestClubFeatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Request a Club'**
  String get settingsRequestClubFeatureTitle;

  /// No description provided for @settingsRequestClubFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'Clubs are coming to Klass! You will soon be able to create and join communities focused on specific subjects and interests.'**
  String get settingsRequestClubFeatureDescription;

  /// No description provided for @settingsRequestClubFeatureName.
  ///
  /// In en, this message translates to:
  /// **'Club Communities'**
  String get settingsRequestClubFeatureName;

  /// No description provided for @settingsRequestClubFeatureHelper.
  ///
  /// In en, this message translates to:
  /// **'Collaborate with other students and teachers in specialized groups.'**
  String get settingsRequestClubFeatureHelper;

  /// No description provided for @settingsRequestClubCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Request New Club'**
  String get settingsRequestClubCardTitle;

  /// No description provided for @settingsRequestClubCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Request a new club for your community'**
  String get settingsRequestClubCardSubtitle;

  /// No description provided for @settingsVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'KLASS VERSION {version}'**
  String settingsVersionLabel(Object version);

  /// No description provided for @settingsLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get settingsLogOut;

  /// No description provided for @featureComingSoonDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'A New Chapter for Your Library'**
  String get featureComingSoonDefaultTitle;

  /// No description provided for @featureComingSoonDefaultDescription.
  ///
  /// In en, this message translates to:
  /// **'We’re busy building this feature for you. It’ll be ready in a future update! Our curators are currently indexing new collections to enhance your experience.'**
  String get featureComingSoonDefaultDescription;

  /// No description provided for @featureComingSoonDefaultFeatureName.
  ///
  /// In en, this message translates to:
  /// **'Enhanced Archiving'**
  String get featureComingSoonDefaultFeatureName;

  /// No description provided for @featureComingSoonDefaultFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'Intelligent cross-referencing for your sources.'**
  String get featureComingSoonDefaultFeatureDescription;

  /// No description provided for @featureComingSoonHeader.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Feature'**
  String get featureComingSoonHeader;

  /// No description provided for @featureComingSoonBadge.
  ///
  /// In en, this message translates to:
  /// **'COMING SOON'**
  String get featureComingSoonBadge;

  /// No description provided for @featureComingSoonDismiss.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get featureComingSoonDismiss;

  /// No description provided for @promptInputHint.
  ///
  /// In en, this message translates to:
  /// **'Type a topic you want to learn...'**
  String get promptInputHint;

  /// No description provided for @animatedSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for teachers, topics...'**
  String get animatedSearchHint;

  /// No description provided for @projectDetailsFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Project'**
  String get projectDetailsFallbackTitle;

  /// No description provided for @projectDetailsOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get projectDetailsOverviewTitle;

  /// No description provided for @projectDetailsNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description provided.'**
  String get projectDetailsNoDescription;

  /// No description provided for @projectDetailsRecreate.
  ///
  /// In en, this message translates to:
  /// **'Recreate'**
  String get projectDetailsRecreate;

  /// No description provided for @projectDetailsUseAsIs.
  ///
  /// In en, this message translates to:
  /// **'Use as it is'**
  String get projectDetailsUseAsIs;

  /// No description provided for @projectConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Project Confirmation'**
  String get projectConfirmationTitle;

  /// No description provided for @projectConfirmationTemplateBadge.
  ///
  /// In en, this message translates to:
  /// **'TEMPLATE'**
  String get projectConfirmationTemplateBadge;

  /// No description provided for @projectConfirmationCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Created by Education Team'**
  String get projectConfirmationCreatedBy;

  /// No description provided for @projectConfirmationFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Botany 101'**
  String get projectConfirmationFallbackTitle;

  /// No description provided for @projectConfirmationDescription.
  ///
  /// In en, this message translates to:
  /// **'Review the modules included in this project before adding it to your workspace. This curated sequence is designed for optimal learning outcomes.'**
  String get projectConfirmationDescription;

  /// No description provided for @projectConfirmationModulesSlides.
  ///
  /// In en, this message translates to:
  /// **'Project Modules (Slides)'**
  String get projectConfirmationModulesSlides;

  /// No description provided for @projectConfirmationModulesPoints.
  ///
  /// In en, this message translates to:
  /// **'Project Modules (Points)'**
  String get projectConfirmationModulesPoints;

  /// No description provided for @projectConfirmationModulesQuiz.
  ///
  /// In en, this message translates to:
  /// **'Project Modules (Quiz)'**
  String get projectConfirmationModulesQuiz;

  /// No description provided for @projectConfirmationModulesTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} Modules Total'**
  String projectConfirmationModulesTotal(int count);

  /// No description provided for @projectConfirmationWorkspaceSlotPrefix.
  ///
  /// In en, this message translates to:
  /// **'Adding this project will use '**
  String get projectConfirmationWorkspaceSlotPrefix;

  /// No description provided for @projectConfirmationWorkspaceSlotHighlight.
  ///
  /// In en, this message translates to:
  /// **'1 workspace slot'**
  String get projectConfirmationWorkspaceSlotHighlight;

  /// No description provided for @projectConfirmationWorkspaceSlotSuffix.
  ///
  /// In en, this message translates to:
  /// **'. You can edit these modules later in your Project Dashboard.'**
  String get projectConfirmationWorkspaceSlotSuffix;

  /// No description provided for @projectConfirmationConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Add to Workspace'**
  String get projectConfirmationConfirm;

  /// No description provided for @projectConfirmationCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get projectConfirmationCancel;

  /// No description provided for @freelancerDetailsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get freelancerDetailsUnknown;

  /// No description provided for @freelancerDetailsPerHour.
  ///
  /// In en, this message translates to:
  /// **'/hr'**
  String get freelancerDetailsPerHour;

  /// No description provided for @freelancerDetailsProjects.
  ///
  /// In en, this message translates to:
  /// **'PROJECTS'**
  String get freelancerDetailsProjects;

  /// No description provided for @freelancerDetailsRating.
  ///
  /// In en, this message translates to:
  /// **'RATING'**
  String get freelancerDetailsRating;

  /// No description provided for @freelancerDetailsResponse.
  ///
  /// In en, this message translates to:
  /// **'RESPONSE'**
  String get freelancerDetailsResponse;

  /// No description provided for @freelancerDetailsHire.
  ///
  /// In en, this message translates to:
  /// **'Hire {name}'**
  String freelancerDetailsHire(Object name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
