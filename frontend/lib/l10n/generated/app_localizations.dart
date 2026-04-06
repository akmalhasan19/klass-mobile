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

  /// No description provided for @projectConfirmationModuleIncluded.
  ///
  /// In en, this message translates to:
  /// **'Included module'**
  String get projectConfirmationModuleIncluded;

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

  /// No description provided for @commonTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get commonTeacher;

  /// No description provided for @commonFreelancer.
  ///
  /// In en, this message translates to:
  /// **'Freelancer'**
  String get commonFreelancer;

  /// No description provided for @commonGuestUser.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get commonGuestUser;

  /// No description provided for @commonGuestBadge.
  ///
  /// In en, this message translates to:
  /// **'GUEST'**
  String get commonGuestBadge;

  /// No description provided for @commonLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get commonLogIn;

  /// No description provided for @commonSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get commonSignUp;

  /// No description provided for @commonEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get commonEmailAddress;

  /// No description provided for @commonPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get commonPassword;

  /// No description provided for @commonFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get commonFullName;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get commonViewAll;

  /// No description provided for @commonCopyDebugInfo.
  ///
  /// In en, this message translates to:
  /// **'Copy Debug Info'**
  String get commonCopyDebugInfo;

  /// No description provided for @commonDebugInfoCopied.
  ///
  /// In en, this message translates to:
  /// **'Debug info copied to clipboard'**
  String get commonDebugInfoCopied;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @commonNoDescriptionAvailable.
  ///
  /// In en, this message translates to:
  /// **'No description available'**
  String get commonNoDescriptionAvailable;

  /// No description provided for @commonPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get commonPublished;

  /// No description provided for @commonDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get commonDraft;

  /// No description provided for @commonUpdatedRecently.
  ///
  /// In en, this message translates to:
  /// **'Updated recently'**
  String get commonUpdatedRecently;

  /// No description provided for @commonSearchMaterials.
  ///
  /// In en, this message translates to:
  /// **'Search materials...'**
  String get commonSearchMaterials;

  /// No description provided for @commonItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String commonItemsCount(int count);

  /// No description provided for @loginTitleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get loginTitleSignIn;

  /// No description provided for @loginTitleSignUp.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get loginTitleSignUp;

  /// No description provided for @loginSubtitleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to jump back into your learning journey.'**
  String get loginSubtitleSignIn;

  /// No description provided for @loginSubtitleSignUp.
  ///
  /// In en, this message translates to:
  /// **'Join Klass and start your journey.'**
  String get loginSubtitleSignUp;

  /// No description provided for @loginRegisterAs.
  ///
  /// In en, this message translates to:
  /// **'Register as:'**
  String get loginRegisterAs;

  /// No description provided for @loginTeacherDescription.
  ///
  /// In en, this message translates to:
  /// **'Create and manage learning materials'**
  String get loginTeacherDescription;

  /// No description provided for @loginFreelancerDescription.
  ///
  /// In en, this message translates to:
  /// **'Offer design services'**
  String get loginFreelancerDescription;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get loginForgotPassword;

  /// No description provided for @loginSubmitSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginSubmitSignIn;

  /// No description provided for @loginSubmitSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up as {role}'**
  String loginSubmitSignUp(Object role);

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully signed in.'**
  String get loginSuccess;

  /// No description provided for @loginSuccessFreelancer.
  ///
  /// In en, this message translates to:
  /// **'Successfully signed in as Freelancer.'**
  String get loginSuccessFreelancer;

  /// No description provided for @loginGenericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get loginGenericError;

  /// No description provided for @loginToggleToSignUp.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get loginToggleToSignUp;

  /// No description provided for @loginToggleToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get loginToggleToSignIn;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitleEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to answer your security question.'**
  String get forgotPasswordSubtitleEnterEmail;

  /// No description provided for @forgotPasswordSubtitleAnswerQuestion.
  ///
  /// In en, this message translates to:
  /// **'Answer your security question to reset your password.'**
  String get forgotPasswordSubtitleAnswerQuestion;

  /// No description provided for @forgotPasswordEnterEmailError.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address.'**
  String get forgotPasswordEnterEmailError;

  /// No description provided for @forgotPasswordNoQuestionFound.
  ///
  /// In en, this message translates to:
  /// **'No security question found for this user.'**
  String get forgotPasswordNoQuestionFound;

  /// No description provided for @forgotPasswordFillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill all fields.'**
  String get forgotPasswordFillAllFields;

  /// No description provided for @forgotPasswordMinLengthError.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get forgotPasswordMinLengthError;

  /// No description provided for @forgotPasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset successful. You can now log in.'**
  String get forgotPasswordSuccess;

  /// No description provided for @forgotPasswordSecurityQuestionLabel.
  ///
  /// In en, this message translates to:
  /// **'Security Question:'**
  String get forgotPasswordSecurityQuestionLabel;

  /// No description provided for @forgotPasswordAnswerHint.
  ///
  /// In en, this message translates to:
  /// **'Your Answer'**
  String get forgotPasswordAnswerHint;

  /// No description provided for @forgotPasswordNewPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get forgotPasswordNewPasswordHint;

  /// No description provided for @forgotPasswordTryAnotherEmail.
  ///
  /// In en, this message translates to:
  /// **'Try another email'**
  String get forgotPasswordTryAnotherEmail;

  /// No description provided for @homeHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate Learning Topics'**
  String get homeHeroTitle;

  /// No description provided for @homeProjectsFallbackSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Project Recommendations'**
  String get homeProjectsFallbackSectionTitle;

  /// No description provided for @homeFreelancersFallbackSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Top Freelancers'**
  String get homeFreelancersFallbackSectionTitle;

  /// No description provided for @homeUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get homeUntitled;

  /// No description provided for @homeByUnknown.
  ///
  /// In en, this message translates to:
  /// **'By Unknown'**
  String get homeByUnknown;

  /// No description provided for @homeCuratedBadge.
  ///
  /// In en, this message translates to:
  /// **'★ Curated'**
  String get homeCuratedBadge;

  /// No description provided for @homeNoProjects.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get homeNoProjects;

  /// No description provided for @homeNoFreelancers.
  ///
  /// In en, this message translates to:
  /// **'No freelancers yet'**
  String get homeNoFreelancers;

  /// No description provided for @projectSourceKlassCurated.
  ///
  /// In en, this message translates to:
  /// **'Klass Curated'**
  String get projectSourceKlassCurated;

  /// No description provided for @projectSourceSystemRecommendation.
  ///
  /// In en, this message translates to:
  /// **'System Recommendation'**
  String get projectSourceSystemRecommendation;

  /// No description provided for @projectSourceKlassApp.
  ///
  /// In en, this message translates to:
  /// **'Klass App'**
  String get projectSourceKlassApp;

  /// No description provided for @debugInfoNetworkRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Network request failed'**
  String get debugInfoNetworkRequestFailed;

  /// No description provided for @debugInfoHomeProjectsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load projects'**
  String get debugInfoHomeProjectsLoadFailed;

  /// No description provided for @debugInfoHomeFreelancersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load freelancers'**
  String get debugInfoHomeFreelancersLoadFailed;

  /// No description provided for @debugInfoWorkspaceMaterialsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load materials'**
  String get debugInfoWorkspaceMaterialsLoadFailed;

  /// No description provided for @debugInfoEndpointLabel.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get debugInfoEndpointLabel;

  /// No description provided for @debugInfoMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get debugInfoMethodLabel;

  /// No description provided for @debugInfoUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get debugInfoUrlLabel;

  /// No description provided for @debugInfoStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get debugInfoStatusLabel;

  /// No description provided for @debugInfoDioTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Dio Type'**
  String get debugInfoDioTypeLabel;

  /// No description provided for @debugInfoErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get debugInfoErrorLabel;

  /// No description provided for @debugInfoBackendMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Backend Message'**
  String get debugInfoBackendMessageLabel;

  /// No description provided for @debugInfoResponseLabel.
  ///
  /// In en, this message translates to:
  /// **'Response'**
  String get debugInfoResponseLabel;

  /// No description provided for @debugInfoInvalidResponseFormatList.
  ///
  /// In en, this message translates to:
  /// **'Invalid response format. Expected data as List.'**
  String get debugInfoInvalidResponseFormatList;

  /// No description provided for @debugInfoUnknownNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Unknown network error'**
  String get debugInfoUnknownNetworkError;

  /// No description provided for @freelancerHomeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}!'**
  String freelancerHomeGreeting(Object name);

  /// No description provided for @freelancerHomeDashboardLabel.
  ///
  /// In en, this message translates to:
  /// **'FREELANCER DASHBOARD'**
  String get freelancerHomeDashboardLabel;

  /// No description provided for @freelancerHomeActiveProjects.
  ///
  /// In en, this message translates to:
  /// **'Active\nProjects'**
  String get freelancerHomeActiveProjects;

  /// No description provided for @freelancerHomePendingOffers.
  ///
  /// In en, this message translates to:
  /// **'Pending\nOffers'**
  String get freelancerHomePendingOffers;

  /// No description provided for @freelancerHomeRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get freelancerHomeRating;

  /// No description provided for @freelancerHomeBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard in Progress'**
  String get freelancerHomeBannerTitle;

  /// No description provided for @freelancerHomeBannerDescription.
  ///
  /// In en, this message translates to:
  /// **'We are building an exceptional freelancer experience for you. Features like finding projects, managing your portfolio, and receiving payments are coming soon.'**
  String get freelancerHomeBannerDescription;

  /// No description provided for @freelancerHomeSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get freelancerHomeSectionTitle;

  /// No description provided for @freelancerHomeFeatureSearchProjects.
  ///
  /// In en, this message translates to:
  /// **'Find Projects'**
  String get freelancerHomeFeatureSearchProjects;

  /// No description provided for @freelancerHomeFeatureSearchProjectsDescription.
  ///
  /// In en, this message translates to:
  /// **'Discover projects that match your expertise'**
  String get freelancerHomeFeatureSearchProjectsDescription;

  /// No description provided for @freelancerHomeFeaturePortfolio.
  ///
  /// In en, this message translates to:
  /// **'Portfolio'**
  String get freelancerHomeFeaturePortfolio;

  /// No description provided for @freelancerHomeFeaturePortfolioDescription.
  ///
  /// In en, this message translates to:
  /// **'Showcase your best work to teachers'**
  String get freelancerHomeFeaturePortfolioDescription;

  /// No description provided for @freelancerHomeFeaturePayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get freelancerHomeFeaturePayments;

  /// No description provided for @freelancerHomeFeaturePaymentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Receive payments easily and securely'**
  String get freelancerHomeFeaturePaymentsDescription;

  /// No description provided for @freelancerHomeFeatureMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get freelancerHomeFeatureMessages;

  /// No description provided for @freelancerHomeFeatureMessagesDescription.
  ///
  /// In en, this message translates to:
  /// **'Communicate directly with teachers'**
  String get freelancerHomeFeatureMessagesDescription;

  /// No description provided for @searchDiscoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get searchDiscoverTitle;

  /// No description provided for @searchDiscoverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'EXPLORE TEACHERS'**
  String get searchDiscoverSubtitle;

  /// No description provided for @searchRecommendedTitle.
  ///
  /// In en, this message translates to:
  /// **'Recommended For You'**
  String get searchRecommendedTitle;

  /// No description provided for @searchCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchCategoryAll;

  /// No description provided for @searchCategoryScience.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get searchCategoryScience;

  /// No description provided for @searchCategoryMath.
  ///
  /// In en, this message translates to:
  /// **'Math'**
  String get searchCategoryMath;

  /// No description provided for @searchCategoryArt.
  ///
  /// In en, this message translates to:
  /// **'Art'**
  String get searchCategoryArt;

  /// No description provided for @searchCategoryCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get searchCategoryCode;

  /// No description provided for @searchCategoryHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get searchCategoryHistory;

  /// No description provided for @searchErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load freelancers'**
  String get searchErrorTitle;

  /// No description provided for @searchErrorDescription.
  ///
  /// In en, this message translates to:
  /// **'There was a problem while fetching data. Debug details are shown below.'**
  String get searchErrorDescription;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No freelancers available'**
  String get searchEmptyTitle;

  /// No description provided for @searchEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Available freelancers will appear here. Try adjusting your search filters.'**
  String get searchEmptyDescription;

  /// No description provided for @searchViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get searchViewProfile;

  /// No description provided for @jobsTitle.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get jobsTitle;

  /// No description provided for @jobsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'MARKETPLACE'**
  String get jobsSubtitle;

  /// No description provided for @jobsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for matching projects...'**
  String get jobsSearchHint;

  /// No description provided for @jobsCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get jobsCategoryAll;

  /// No description provided for @jobsCategoryDesign.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get jobsCategoryDesign;

  /// No description provided for @jobsCategoryContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get jobsCategoryContent;

  /// No description provided for @jobsCategoryVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get jobsCategoryVideo;

  /// No description provided for @jobsCategoryPresentation.
  ///
  /// In en, this message translates to:
  /// **'Presentation'**
  String get jobsCategoryPresentation;

  /// No description provided for @jobsComingSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Marketplace Coming Soon'**
  String get jobsComingSoonTitle;

  /// No description provided for @jobsComingSoonDescription.
  ///
  /// In en, this message translates to:
  /// **'You will be able to browse and apply for teacher projects here. The marketplace is currently under active development.'**
  String get jobsComingSoonDescription;

  /// No description provided for @portfolioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'YOUR WORK'**
  String get portfolioSubtitle;

  /// No description provided for @portfolioAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get portfolioAdd;

  /// No description provided for @portfolioStatsWorks.
  ///
  /// In en, this message translates to:
  /// **'Works'**
  String get portfolioStatsWorks;

  /// No description provided for @portfolioStatsViewed.
  ///
  /// In en, this message translates to:
  /// **'Viewed'**
  String get portfolioStatsViewed;

  /// No description provided for @portfolioStatsLiked.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get portfolioStatsLiked;

  /// No description provided for @portfolioComingSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Portfolio Coming Soon'**
  String get portfolioComingSoonTitle;

  /// No description provided for @portfolioComingSoonDescription.
  ///
  /// In en, this message translates to:
  /// **'Showcase your best work, from learning materials and presentations to educational content, to attract teachers.'**
  String get portfolioComingSoonDescription;

  /// No description provided for @galleryLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load gallery'**
  String get galleryLoadError;

  /// No description provided for @galleryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No materials in Gallery'**
  String get galleryEmptyTitle;

  /// No description provided for @galleryUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get galleryUntitled;

  /// No description provided for @galleryCategoryMiscellaneous.
  ///
  /// In en, this message translates to:
  /// **'Miscellaneous'**
  String get galleryCategoryMiscellaneous;

  /// No description provided for @galleryFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter Materials'**
  String get galleryFilterTitle;

  /// No description provided for @galleryFilterClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get galleryFilterClearAll;

  /// No description provided for @galleryFilterSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search materials, tags, or topics...'**
  String get galleryFilterSearchHint;

  /// No description provided for @galleryFilterSubject.
  ///
  /// In en, this message translates to:
  /// **'SUBJECT'**
  String get galleryFilterSubject;

  /// No description provided for @galleryFilterResourceType.
  ///
  /// In en, this message translates to:
  /// **'RESOURCE TYPE'**
  String get galleryFilterResourceType;

  /// No description provided for @galleryFilterDateAdded.
  ///
  /// In en, this message translates to:
  /// **'DATE ADDED'**
  String get galleryFilterDateAdded;

  /// No description provided for @galleryFilterSubjectMath.
  ///
  /// In en, this message translates to:
  /// **'Math'**
  String get galleryFilterSubjectMath;

  /// No description provided for @galleryFilterSubjectScience.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get galleryFilterSubjectScience;

  /// No description provided for @galleryFilterSubjectHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get galleryFilterSubjectHistory;

  /// No description provided for @galleryFilterSubjectLiterature.
  ///
  /// In en, this message translates to:
  /// **'Literature'**
  String get galleryFilterSubjectLiterature;

  /// No description provided for @galleryFilterSubjectArt.
  ///
  /// In en, this message translates to:
  /// **'Art'**
  String get galleryFilterSubjectArt;

  /// No description provided for @galleryFilterSubjectGeography.
  ///
  /// In en, this message translates to:
  /// **'Geography'**
  String get galleryFilterSubjectGeography;

  /// No description provided for @galleryFilterTypePdfs.
  ///
  /// In en, this message translates to:
  /// **'PDFs'**
  String get galleryFilterTypePdfs;

  /// No description provided for @galleryFilterTypeImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get galleryFilterTypeImages;

  /// No description provided for @galleryFilterTypeWorksheets.
  ///
  /// In en, this message translates to:
  /// **'Worksheets'**
  String get galleryFilterTypeWorksheets;

  /// No description provided for @galleryFilterTypeVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get galleryFilterTypeVideos;

  /// No description provided for @galleryFilterTypeLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get galleryFilterTypeLinks;

  /// No description provided for @galleryFilterDateAnytime.
  ///
  /// In en, this message translates to:
  /// **'Anytime'**
  String get galleryFilterDateAnytime;

  /// No description provided for @galleryFilterDatePastWeek.
  ///
  /// In en, this message translates to:
  /// **'Past Week'**
  String get galleryFilterDatePastWeek;

  /// No description provided for @galleryFilterDatePastMonth.
  ///
  /// In en, this message translates to:
  /// **'Past Month'**
  String get galleryFilterDatePastMonth;

  /// No description provided for @galleryFilterDatePastYear.
  ///
  /// In en, this message translates to:
  /// **'Past Year'**
  String get galleryFilterDatePastYear;

  /// No description provided for @galleryFilterShowResults.
  ///
  /// In en, this message translates to:
  /// **'Show {count} Results'**
  String galleryFilterShowResults(int count);

  /// No description provided for @helpCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenterTitle;

  /// No description provided for @helpHeadline.
  ///
  /// In en, this message translates to:
  /// **'How can we help?'**
  String get helpHeadline;

  /// No description provided for @helpSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for articles, guides...'**
  String get helpSearchHint;

  /// No description provided for @helpQuickHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Help'**
  String get helpQuickHelpTitle;

  /// No description provided for @helpGettingStartedTitle.
  ///
  /// In en, this message translates to:
  /// **'Getting Started'**
  String get helpGettingStartedTitle;

  /// No description provided for @helpGettingStartedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Learn the basics'**
  String get helpGettingStartedSubtitle;

  /// No description provided for @helpUserGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'User Guide'**
  String get helpUserGuideTitle;

  /// No description provided for @helpUserGuideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Detailed tutorials'**
  String get helpUserGuideSubtitle;

  /// No description provided for @helpPopularQuestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Popular Questions'**
  String get helpPopularQuestionsTitle;

  /// No description provided for @helpQuestionNewModule.
  ///
  /// In en, this message translates to:
  /// **'How do I create a new module?'**
  String get helpQuestionNewModule;

  /// No description provided for @helpQuestionSyncSchoolData.
  ///
  /// In en, this message translates to:
  /// **'Can I sync my school data?'**
  String get helpQuestionSyncSchoolData;

  /// No description provided for @helpQuestionShareMaterials.
  ///
  /// In en, this message translates to:
  /// **'How do I share materials with students?'**
  String get helpQuestionShareMaterials;

  /// No description provided for @helpQuestionVerifiedInstructor.
  ///
  /// In en, this message translates to:
  /// **'What is a verified instructor profile?'**
  String get helpQuestionVerifiedInstructor;

  /// No description provided for @helpStillNeedHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Still need help?'**
  String get helpStillNeedHelpTitle;

  /// No description provided for @helpStillNeedHelpDescription.
  ///
  /// In en, this message translates to:
  /// **'Our support team is available 24/7 to assist you with any issues.'**
  String get helpStillNeedHelpDescription;

  /// No description provided for @helpContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get helpContactSupport;

  /// No description provided for @projectSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Project Added Successfully!'**
  String get projectSuccessTitle;

  /// No description provided for @projectSuccessDescription.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" has been successfully added to your educational materials. You can now start editing or sharing it with your students.'**
  String projectSuccessDescription(Object title);

  /// No description provided for @projectSuccessProjectTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'PROJECT TITLE'**
  String get projectSuccessProjectTitleLabel;

  /// No description provided for @projectSuccessNewBadge.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get projectSuccessNewBadge;

  /// No description provided for @projectSuccessModulesLabel.
  ///
  /// In en, this message translates to:
  /// **'MODULES'**
  String get projectSuccessModulesLabel;

  /// No description provided for @projectSuccessUnits.
  ///
  /// In en, this message translates to:
  /// **'{count} Units'**
  String projectSuccessUnits(int count);

  /// No description provided for @projectSuccessAccessLabel.
  ///
  /// In en, this message translates to:
  /// **'ACCESS'**
  String get projectSuccessAccessLabel;

  /// No description provided for @projectSuccessGoToWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Go to Workspace'**
  String get projectSuccessGoToWorkspace;

  /// No description provided for @projectSuccessExploreMoreProjects.
  ///
  /// In en, this message translates to:
  /// **'Explore More Projects'**
  String get projectSuccessExploreMoreProjects;

  /// No description provided for @commonSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get commonSaveChanges;

  /// No description provided for @commonDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get commonDeleteAccount;

  /// No description provided for @commonChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get commonChangePassword;

  /// No description provided for @commonPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get commonPrivacyPolicy;

  /// No description provided for @workspaceHeaderHeadline.
  ///
  /// In en, this message translates to:
  /// **'Manage your work.'**
  String get workspaceHeaderHeadline;

  /// No description provided for @workspaceHeaderDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage curriculum materials, organize new lecture ideas, and keep your digital workspace in order.'**
  String get workspaceHeaderDescription;

  /// No description provided for @workspaceFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get workspaceFilterAll;

  /// No description provided for @workspaceFilterDrafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get workspaceFilterDrafts;

  /// No description provided for @workspaceFilterPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get workspaceFilterPublished;

  /// No description provided for @workspaceFilterStudentMaterials.
  ///
  /// In en, this message translates to:
  /// **'Student Materials'**
  String get workspaceFilterStudentMaterials;

  /// No description provided for @workspaceMaterialsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Teaching Materials'**
  String get workspaceMaterialsTitle;

  /// No description provided for @workspaceViewGallery.
  ///
  /// In en, this message translates to:
  /// **'View Gallery'**
  String get workspaceViewGallery;

  /// No description provided for @workspaceLoadErrorFallback.
  ///
  /// In en, this message translates to:
  /// **'Failed to load materials'**
  String get workspaceLoadErrorFallback;

  /// No description provided for @workspaceEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No materials to display yet'**
  String get workspaceEmptyTitle;

  /// No description provided for @workspaceEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a project first. Materials will appear here after the project is created.'**
  String get workspaceEmptyDescription;

  /// No description provided for @workspaceFirstProjectCta.
  ///
  /// In en, this message translates to:
  /// **'Create Your First Project'**
  String get workspaceFirstProjectCta;

  /// No description provided for @workspaceCreateNewModule.
  ///
  /// In en, this message translates to:
  /// **'Create New Module'**
  String get workspaceCreateNewModule;

  /// No description provided for @workspaceCreateNewModuleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start building your next masterpiece'**
  String get workspaceCreateNewModuleSubtitle;

  /// No description provided for @workspaceDraftsTitle.
  ///
  /// In en, this message translates to:
  /// **'Drafts & Ideas'**
  String get workspaceDraftsTitle;

  /// No description provided for @workspaceDraftSampleOne.
  ///
  /// In en, this message translates to:
  /// **'Compare the ecological impact of traditional vs modern farming in Java...'**
  String get workspaceDraftSampleOne;

  /// No description provided for @workspaceDraftSampleTwo.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary quiz for Semester 2 - Advanced Literature...'**
  String get workspaceDraftSampleTwo;

  /// No description provided for @workspaceQuickCapture.
  ///
  /// In en, this message translates to:
  /// **'Quick Capture'**
  String get workspaceQuickCapture;

  /// No description provided for @workspaceResourceLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Resource Library'**
  String get workspaceResourceLibraryTitle;

  /// No description provided for @workspaceResourceTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get workspaceResourceTemplates;

  /// No description provided for @workspaceResourceAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get workspaceResourceAssets;

  /// No description provided for @workspaceResourceLectures.
  ///
  /// In en, this message translates to:
  /// **'Lectures'**
  String get workspaceResourceLectures;

  /// No description provided for @workspaceResourceUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get workspaceResourceUpload;

  /// No description provided for @workspaceStorageFull.
  ///
  /// In en, this message translates to:
  /// **'Storage {percent}% full'**
  String workspaceStorageFull(int percent);

  /// No description provided for @workspaceFeatureLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'{label} Library'**
  String workspaceFeatureLibraryTitle(Object label);

  /// No description provided for @workspaceFeatureLibraryDescription.
  ///
  /// In en, this message translates to:
  /// **'The {label} section of your Resource Library is currently under construction. Soon you will be able to manage all your educational assets in one place.'**
  String workspaceFeatureLibraryDescription(Object label);

  /// No description provided for @workspaceFeatureCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get workspaceFeatureCloudSync;

  /// No description provided for @workspaceFeatureCloudSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Access your {label} from any device, anywhere.'**
  String workspaceFeatureCloudSyncDescription(Object label);

  /// No description provided for @profileGuestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You are currently browsing as a guest'**
  String get profileGuestSubtitle;

  /// No description provided for @profileJoinTeacherTitle.
  ///
  /// In en, this message translates to:
  /// **'Join as Teacher'**
  String get profileJoinTeacherTitle;

  /// No description provided for @profileJoinTeacherSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share your expertise and build your academic legacy.'**
  String get profileJoinTeacherSubtitle;

  /// No description provided for @profileJoinTeacherLabel.
  ///
  /// In en, this message translates to:
  /// **'Opportunity'**
  String get profileJoinTeacherLabel;

  /// No description provided for @profileJoinTeacherCta.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get profileJoinTeacherCta;

  /// No description provided for @profileTeacherRegistrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Teacher Registration'**
  String get profileTeacherRegistrationTitle;

  /// No description provided for @profileTeacherRegistrationDescription.
  ///
  /// In en, this message translates to:
  /// **'Become an educator and start sharing your knowledge today.'**
  String get profileTeacherRegistrationDescription;

  /// No description provided for @profileTeacherRegistrationFeatureName.
  ///
  /// In en, this message translates to:
  /// **'Teacher Ecosystem'**
  String get profileTeacherRegistrationFeatureName;

  /// No description provided for @profileTeacherRegistrationFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'Access tools for course creation and student management.'**
  String get profileTeacherRegistrationFeatureDescription;

  /// No description provided for @profileJoinFreelancerTitle.
  ///
  /// In en, this message translates to:
  /// **'Join as Freelancer'**
  String get profileJoinFreelancerTitle;

  /// No description provided for @profileJoinFreelancerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Work on your own terms with high-tier educational projects.'**
  String get profileJoinFreelancerSubtitle;

  /// No description provided for @profileJoinFreelancerLabel.
  ///
  /// In en, this message translates to:
  /// **'Flexibility'**
  String get profileJoinFreelancerLabel;

  /// No description provided for @profileJoinFreelancerCta.
  ///
  /// In en, this message translates to:
  /// **'Learn More'**
  String get profileJoinFreelancerCta;

  /// No description provided for @profileFreelancerPortalTitle.
  ///
  /// In en, this message translates to:
  /// **'Freelancer Portal'**
  String get profileFreelancerPortalTitle;

  /// No description provided for @profileFreelancerPortalDescription.
  ///
  /// In en, this message translates to:
  /// **'Register as a freelancer to participate in educational projects.'**
  String get profileFreelancerPortalDescription;

  /// No description provided for @profileFreelancerPortalFeatureName.
  ///
  /// In en, this message translates to:
  /// **'Klass Freelance'**
  String get profileFreelancerPortalFeatureName;

  /// No description provided for @profileFreelancerPortalFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'Flexible work opportunities for experts.'**
  String get profileFreelancerPortalFeatureDescription;

  /// No description provided for @profileReturnTitle.
  ///
  /// In en, this message translates to:
  /// **'Return to your journey'**
  String get profileReturnTitle;

  /// No description provided for @profileReturnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Access your curated classes and achievements.'**
  String get profileReturnSubtitle;

  /// No description provided for @profileQuote.
  ///
  /// In en, this message translates to:
  /// **'\"Knowledge is a curated gallery of the mind; begin your exhibition today.\"'**
  String get profileQuote;

  /// No description provided for @profileVerifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'VERIFIED'**
  String get profileVerifiedBadge;

  /// No description provided for @profileRoleTeacherBadge.
  ///
  /// In en, this message translates to:
  /// **'TEACHER'**
  String get profileRoleTeacherBadge;

  /// No description provided for @profileRoleFreelancerBadge.
  ///
  /// In en, this message translates to:
  /// **'FREELANCER'**
  String get profileRoleFreelancerBadge;

  /// No description provided for @profileYearsInEducation.
  ///
  /// In en, this message translates to:
  /// **'12 Years in Education'**
  String get profileYearsInEducation;

  /// No description provided for @profileClassDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Class Dashboard'**
  String get profileClassDashboardTitle;

  /// No description provided for @profileClassDashboardDescription.
  ///
  /// In en, this message translates to:
  /// **'The Class Dashboard is being refined to provide you with a comprehensive overview of your teaching performance and student engagement metrics.'**
  String get profileClassDashboardDescription;

  /// No description provided for @profileClassDashboardFeatureName.
  ///
  /// In en, this message translates to:
  /// **'Performance Analytics'**
  String get profileClassDashboardFeatureName;

  /// No description provided for @profileClassDashboardFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'Real-time data on class participation and curriculum progress.'**
  String get profileClassDashboardFeatureDescription;

  /// No description provided for @profileStatsClassesTaught.
  ///
  /// In en, this message translates to:
  /// **'Classes Taught'**
  String get profileStatsClassesTaught;

  /// No description provided for @profileStatsActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get profileStatsActive;

  /// No description provided for @profileStatsStudentCount.
  ///
  /// In en, this message translates to:
  /// **'Student Count'**
  String get profileStatsStudentCount;

  /// No description provided for @profileStatsEnrolled.
  ///
  /// In en, this message translates to:
  /// **'Enrolled'**
  String get profileStatsEnrolled;

  /// No description provided for @profileStatsCurriculumHours.
  ///
  /// In en, this message translates to:
  /// **'Curriculum Hours'**
  String get profileStatsCurriculumHours;

  /// No description provided for @profileStatsHoursPerWeek.
  ///
  /// In en, this message translates to:
  /// **'h/week'**
  String get profileStatsHoursPerWeek;

  /// No description provided for @profileInstitutionalToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Institutional Tools'**
  String get profileInstitutionalToolsTitle;

  /// No description provided for @profileToolGradebookAttendance.
  ///
  /// In en, this message translates to:
  /// **'Gradebook &\nAttendance'**
  String get profileToolGradebookAttendance;

  /// No description provided for @profileToolCurriculumPlanner.
  ///
  /// In en, this message translates to:
  /// **'Curriculum\nPlanner'**
  String get profileToolCurriculumPlanner;

  /// No description provided for @profileToolSchoolAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'School\nAnnouncements'**
  String get profileToolSchoolAnnouncements;

  /// No description provided for @profileToolParentPortal.
  ///
  /// In en, this message translates to:
  /// **'Parent\nPortal'**
  String get profileToolParentPortal;

  /// No description provided for @profileInstitutionalToolDescription.
  ///
  /// In en, this message translates to:
  /// **'We are working on bringing {label} directly to your mobile device for seamless institutional management.'**
  String profileInstitutionalToolDescription(Object label);

  /// No description provided for @profileInstitutionalSyncFeatureName.
  ///
  /// In en, this message translates to:
  /// **'Institutional Sync'**
  String get profileInstitutionalSyncFeatureName;

  /// No description provided for @profileInstitutionalSyncFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'Stay connected with your school\'s management systems on the go.'**
  String get profileInstitutionalSyncFeatureDescription;

  /// No description provided for @profileTeachingMaterialsTitle.
  ///
  /// In en, this message translates to:
  /// **'Curriculum Modules'**
  String get profileTeachingMaterialsTitle;

  /// No description provided for @profileTeachingMaterialsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage and review your educational curriculum.'**
  String get profileTeachingMaterialsSubtitle;

  /// No description provided for @profileModuleOneTitle.
  ///
  /// In en, this message translates to:
  /// **'Intro to Quantum Physics'**
  String get profileModuleOneTitle;

  /// No description provided for @profileModuleOneDescription.
  ///
  /// In en, this message translates to:
  /// **'A comprehensive journey from classical mechanics to the mysteries of quantum entanglements.'**
  String get profileModuleOneDescription;

  /// No description provided for @profileModuleOneStats.
  ///
  /// In en, this message translates to:
  /// **'1.2k students · 14h'**
  String get profileModuleOneStats;

  /// No description provided for @profileModuleTwoTitle.
  ///
  /// In en, this message translates to:
  /// **'Modern Art History'**
  String get profileModuleTwoTitle;

  /// No description provided for @profileModuleTwoDescription.
  ///
  /// In en, this message translates to:
  /// **'Exploring the seismic shifts in artistic expression from the mid-19th century to today.'**
  String get profileModuleTwoDescription;

  /// No description provided for @profileModuleTwoStats.
  ///
  /// In en, this message translates to:
  /// **'850 students · 8h'**
  String get profileModuleTwoStats;

  /// No description provided for @profileModuleThreeTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced Thermodynamics'**
  String get profileModuleThreeTitle;

  /// No description provided for @profileModuleThreeDescription.
  ///
  /// In en, this message translates to:
  /// **'In-depth analysis of entropy, enthalpy, and energy conversion systems.'**
  String get profileModuleThreeDescription;

  /// No description provided for @profileModuleThreeStats.
  ///
  /// In en, this message translates to:
  /// **'4/12 Modules'**
  String get profileModuleThreeStats;

  /// No description provided for @profileAccountSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Account & Support'**
  String get profileAccountSupportTitle;

  /// No description provided for @profileAccountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get profileAccountSettings;

  /// No description provided for @profileHelpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get profileHelpCenter;

  /// No description provided for @profileRegisterFreelancer.
  ///
  /// In en, this message translates to:
  /// **'Register as Freelancer'**
  String get profileRegisterFreelancer;

  /// No description provided for @profileLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get profileLogout;

  /// No description provided for @profileLogInCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Log In / Create Account'**
  String get profileLogInCreateAccount;

  /// No description provided for @profileFreelancerRegistrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Freelancer Registration'**
  String get profileFreelancerRegistrationTitle;

  /// No description provided for @profileFreelancerRegistrationDescription.
  ///
  /// In en, this message translates to:
  /// **'Our freelancer registration portal is currently under construction.'**
  String get profileFreelancerRegistrationDescription;

  /// No description provided for @profileFreelancerRegistrationFeatureName.
  ///
  /// In en, this message translates to:
  /// **'Become a Teacher'**
  String get profileFreelancerRegistrationFeatureName;

  /// No description provided for @profileFreelancerRegistrationFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'Share your curriculum and earn from your creations.'**
  String get profileFreelancerRegistrationFeatureDescription;

  /// No description provided for @profileFreelancerProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Freelancer Profile'**
  String get profileFreelancerProfileTitle;

  /// No description provided for @profileSkillsTitle.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get profileSkillsTitle;

  /// No description provided for @profileSkillGraphicDesign.
  ///
  /// In en, this message translates to:
  /// **'Graphic Design'**
  String get profileSkillGraphicDesign;

  /// No description provided for @profileSkillPresentation.
  ///
  /// In en, this message translates to:
  /// **'Presentation'**
  String get profileSkillPresentation;

  /// No description provided for @profileSkillVideoEditing.
  ///
  /// In en, this message translates to:
  /// **'Video Editing'**
  String get profileSkillVideoEditing;

  /// No description provided for @profileSkillEducationalContent.
  ///
  /// In en, this message translates to:
  /// **'Educational Content'**
  String get profileSkillEducationalContent;

  /// No description provided for @profileSkillsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Edit Skills — Coming Soon'**
  String get profileSkillsComingSoon;

  /// No description provided for @profilePortfolioStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Portfolio Statistics'**
  String get profilePortfolioStatsTitle;

  /// No description provided for @profilePortfolioStatsDescription.
  ///
  /// In en, this message translates to:
  /// **'Performance metrics and reviews from teachers will appear here.'**
  String get profilePortfolioStatsDescription;

  /// No description provided for @accountSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettingsTitle;

  /// No description provided for @accountSettingsVerifiedTeacher.
  ///
  /// In en, this message translates to:
  /// **'VERIFIED TEACHER'**
  String get accountSettingsVerifiedTeacher;

  /// No description provided for @accountSettingsUserStudentRole.
  ///
  /// In en, this message translates to:
  /// **'User / Student'**
  String get accountSettingsUserStudentRole;

  /// No description provided for @accountSettingsPreviewPublicProfile.
  ///
  /// In en, this message translates to:
  /// **'Preview Public Profile'**
  String get accountSettingsPreviewPublicProfile;

  /// No description provided for @accountSettingsPersonalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get accountSettingsPersonalInformation;

  /// No description provided for @accountSettingsShortBioLabel.
  ///
  /// In en, this message translates to:
  /// **'SHORT BIO'**
  String get accountSettingsShortBioLabel;

  /// No description provided for @accountSettingsNoBioProvided.
  ///
  /// In en, this message translates to:
  /// **'No bio provided.'**
  String get accountSettingsNoBioProvided;

  /// No description provided for @accountSettingsHintFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get accountSettingsHintFullName;

  /// No description provided for @accountSettingsHintEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get accountSettingsHintEmailAddress;

  /// No description provided for @accountSettingsHintShortBio.
  ///
  /// In en, this message translates to:
  /// **'Tell people a bit about yourself'**
  String get accountSettingsHintShortBio;

  /// No description provided for @accountSettingsTeachingPreferences.
  ///
  /// In en, this message translates to:
  /// **'Teaching Preferences'**
  String get accountSettingsTeachingPreferences;

  /// No description provided for @accountSettingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get accountSettingsNotifications;

  /// No description provided for @accountSettingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get accountSettingsSecurity;

  /// No description provided for @accountSettingsEmailNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Email Notifications'**
  String get accountSettingsEmailNotificationsTitle;

  /// No description provided for @accountSettingsEmailNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Class alerts and messages'**
  String get accountSettingsEmailNotificationsSubtitle;

  /// No description provided for @accountSettingsPushNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get accountSettingsPushNotificationsTitle;

  /// No description provided for @accountSettingsPushNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Real-time mobile updates'**
  String get accountSettingsPushNotificationsSubtitle;

  /// No description provided for @accountSettingsWeeklyReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly Student Reports'**
  String get accountSettingsWeeklyReportsTitle;

  /// No description provided for @accountSettingsWeeklyReportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Aggregated progress insights'**
  String get accountSettingsWeeklyReportsSubtitle;

  /// No description provided for @accountSettingsSecuritySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Security Settings'**
  String get accountSettingsSecuritySettingsTitle;

  /// No description provided for @accountSettingsSecuritySettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'We are enhancing our security features. You will soon be able to change your password, enable two-factor authentication, and manage active sessions.'**
  String get accountSettingsSecuritySettingsDescription;

  /// No description provided for @accountSettingsSecuritySettingsFeatureName.
  ///
  /// In en, this message translates to:
  /// **'Two-Factor Auth'**
  String get accountSettingsSecuritySettingsFeatureName;

  /// No description provided for @accountSettingsSecuritySettingsFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'Add an extra layer of protection to your account.'**
  String get accountSettingsSecuritySettingsFeatureDescription;

  /// No description provided for @accountSettingsPrivacyLegalTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Legal'**
  String get accountSettingsPrivacyLegalTitle;

  /// No description provided for @accountSettingsPrivacyLegalDescription.
  ///
  /// In en, this message translates to:
  /// **'Our legal team is finalizing the updated privacy policy and terms of service to ensure full compliance with the latest regulations.'**
  String get accountSettingsPrivacyLegalDescription;

  /// No description provided for @accountSettingsPrivacyLegalFeatureName.
  ///
  /// In en, this message translates to:
  /// **'Data Export'**
  String get accountSettingsPrivacyLegalFeatureName;

  /// No description provided for @accountSettingsPrivacyLegalFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'Download a complete copy of your personal data at any time.'**
  String get accountSettingsPrivacyLegalFeatureDescription;

  /// No description provided for @accountSettingsAccountManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Management'**
  String get accountSettingsAccountManagementTitle;

  /// No description provided for @accountSettingsAccountManagementDescription.
  ///
  /// In en, this message translates to:
  /// **'We are working on a streamlined process for account deletion and data archival to respect your right to be forgotten.'**
  String get accountSettingsAccountManagementDescription;

  /// No description provided for @accountSettingsAccountManagementFeatureName.
  ///
  /// In en, this message translates to:
  /// **'Data Archival'**
  String get accountSettingsAccountManagementFeatureName;

  /// No description provided for @accountSettingsAccountManagementFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'Archive your account instead of deleting it to preserve your work.'**
  String get accountSettingsAccountManagementFeatureDescription;

  /// No description provided for @accountSettingsDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This action is permanent and will remove all your class materials and student data.'**
  String get accountSettingsDeleteWarning;

  /// No description provided for @accountSettingsAvatarUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated successfully'**
  String get accountSettingsAvatarUpdatedSuccess;

  /// No description provided for @accountSettingsAvatarUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload: {error}'**
  String accountSettingsAvatarUploadFailed(Object error);
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
