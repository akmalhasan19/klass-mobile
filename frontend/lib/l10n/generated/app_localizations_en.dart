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
  String get projectConfirmationModuleIncluded => 'Included module';

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

  @override
  String get commonTeacher => 'Teacher';

  @override
  String get commonFreelancer => 'Freelancer';

  @override
  String get commonGuestUser => 'Guest User';

  @override
  String get commonGuestBadge => 'GUEST';

  @override
  String get commonLogIn => 'Log In';

  @override
  String get commonSignUp => 'Sign Up';

  @override
  String get commonEmailAddress => 'Email Address';

  @override
  String get commonPassword => 'Password';

  @override
  String get commonFullName => 'Full Name';

  @override
  String get commonNext => 'Next';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonViewAll => 'View All';

  @override
  String get commonCopyDebugInfo => 'Copy Debug Info';

  @override
  String get commonDebugInfoCopied => 'Debug info copied to clipboard';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonNoDescriptionAvailable => 'No description available';

  @override
  String get commonPublished => 'Published';

  @override
  String get commonDraft => 'Draft';

  @override
  String get commonUpdatedRecently => 'Updated recently';

  @override
  String get commonSearchMaterials => 'Search materials...';

  @override
  String commonItemsCount(int count) {
    return '$count items';
  }

  @override
  String get loginTitleSignIn => 'Welcome Back';

  @override
  String get loginTitleSignUp => 'Create Account';

  @override
  String get loginSubtitleSignIn =>
      'Sign in to jump back into your learning journey.';

  @override
  String get loginSubtitleSignUp => 'Join Klass and start your journey.';

  @override
  String get loginRegisterAs => 'Register as:';

  @override
  String get loginTeacherDescription => 'Create and manage learning materials';

  @override
  String get loginFreelancerDescription => 'Offer design services';

  @override
  String get loginForgotPassword => 'Forgot Password?';

  @override
  String get loginSubmitSignIn => 'Sign In';

  @override
  String loginSubmitSignUp(Object role) {
    return 'Sign Up as $role';
  }

  @override
  String get loginSuccess => 'Successfully signed in.';

  @override
  String get loginSuccessFreelancer => 'Successfully signed in as Freelancer.';

  @override
  String get loginGenericError => 'Something went wrong. Please try again.';

  @override
  String get loginToggleToSignUp => 'Don\'t have an account? Sign up';

  @override
  String get loginToggleToSignIn => 'Already have an account? Sign in';

  @override
  String get forgotPasswordTitle => 'Reset Password';

  @override
  String get forgotPasswordSubtitleEnterEmail =>
      'Enter your email to answer your security question.';

  @override
  String get forgotPasswordSubtitleAnswerQuestion =>
      'Answer your security question to reset your password.';

  @override
  String get forgotPasswordEnterEmailError =>
      'Please enter your email address.';

  @override
  String get forgotPasswordNoQuestionFound =>
      'No security question found for this user.';

  @override
  String get forgotPasswordFillAllFields => 'Please fill all fields.';

  @override
  String get forgotPasswordMinLengthError =>
      'Password must be at least 6 characters.';

  @override
  String get forgotPasswordSuccess =>
      'Password reset successful. You can now log in.';

  @override
  String get forgotPasswordSecurityQuestionLabel => 'Security Question:';

  @override
  String get forgotPasswordAnswerHint => 'Your Answer';

  @override
  String get forgotPasswordNewPasswordHint => 'New Password';

  @override
  String get forgotPasswordTryAnotherEmail => 'Try another email';

  @override
  String get homeHeroTitle => 'Generate Learning Topics';

  @override
  String get homeProjectsFallbackSectionTitle => 'Project Recommendations';

  @override
  String get homeFreelancersFallbackSectionTitle => 'Top Freelancers';

  @override
  String get homeUntitled => 'Untitled';

  @override
  String get homeByUnknown => 'By Unknown';

  @override
  String get homeCuratedBadge => '★ Curated';

  @override
  String get homeNoProjects => 'No projects yet';

  @override
  String get homeNoFreelancers => 'No freelancers yet';

  @override
  String get projectSourceKlassCurated => 'Klass Curated';

  @override
  String get projectSourceSystemRecommendation => 'System Recommendation';

  @override
  String get projectSourceKlassApp => 'Klass App';

  @override
  String get debugInfoNetworkRequestFailed => 'Network request failed';

  @override
  String get debugInfoHomeProjectsLoadFailed => 'Failed to load projects';

  @override
  String get debugInfoHomeFreelancersLoadFailed => 'Failed to load freelancers';

  @override
  String get debugInfoWorkspaceMaterialsLoadFailed =>
      'Failed to load materials';

  @override
  String get debugInfoEndpointLabel => 'Endpoint';

  @override
  String get debugInfoMethodLabel => 'Method';

  @override
  String get debugInfoUrlLabel => 'URL';

  @override
  String get debugInfoStatusLabel => 'Status';

  @override
  String get debugInfoDioTypeLabel => 'Dio Type';

  @override
  String get debugInfoErrorLabel => 'Error';

  @override
  String get debugInfoBackendMessageLabel => 'Backend Message';

  @override
  String get debugInfoResponseLabel => 'Response';

  @override
  String get debugInfoInvalidResponseFormatList =>
      'Invalid response format. Expected data as List.';

  @override
  String get debugInfoUnknownNetworkError => 'Unknown network error';

  @override
  String freelancerHomeGreeting(Object name) {
    return 'Hi, $name!';
  }

  @override
  String get freelancerHomeDashboardLabel => 'FREELANCER DASHBOARD';

  @override
  String get freelancerHomeActiveProjects => 'Active\nProjects';

  @override
  String get freelancerHomePendingOffers => 'Pending\nOffers';

  @override
  String get freelancerHomeRating => 'Rating';

  @override
  String get freelancerHomeBannerTitle => 'Dashboard in Progress';

  @override
  String get freelancerHomeBannerDescription =>
      'We are building an exceptional freelancer experience for you. Features like finding projects, managing your portfolio, and receiving payments are coming soon.';

  @override
  String get freelancerHomeSectionTitle => 'Coming Soon';

  @override
  String get freelancerHomeFeatureSearchProjects => 'Find Projects';

  @override
  String get freelancerHomeFeatureSearchProjectsDescription =>
      'Discover projects that match your expertise';

  @override
  String get freelancerHomeFeaturePortfolio => 'Portfolio';

  @override
  String get freelancerHomeFeaturePortfolioDescription =>
      'Showcase your best work to teachers';

  @override
  String get freelancerHomeFeaturePayments => 'Payments';

  @override
  String get freelancerHomeFeaturePaymentsDescription =>
      'Receive payments easily and securely';

  @override
  String get freelancerHomeFeatureMessages => 'Messages';

  @override
  String get freelancerHomeFeatureMessagesDescription =>
      'Communicate directly with teachers';

  @override
  String get searchDiscoverTitle => 'Discover';

  @override
  String get searchDiscoverSubtitle => 'EXPLORE TEACHERS';

  @override
  String get searchRecommendedTitle => 'Recommended For You';

  @override
  String get searchCategoryAll => 'All';

  @override
  String get searchCategoryScience => 'Science';

  @override
  String get searchCategoryMath => 'Math';

  @override
  String get searchCategoryArt => 'Art';

  @override
  String get searchCategoryCode => 'Code';

  @override
  String get searchCategoryHistory => 'History';

  @override
  String get searchErrorTitle => 'Failed to load freelancers';

  @override
  String get searchErrorDescription =>
      'There was a problem while fetching data. Debug details are shown below.';

  @override
  String get searchEmptyTitle => 'No freelancers available';

  @override
  String get searchEmptyDescription =>
      'Available freelancers will appear here. Try adjusting your search filters.';

  @override
  String get searchViewProfile => 'View Profile';

  @override
  String get jobsTitle => 'Jobs';

  @override
  String get jobsSubtitle => 'MARKETPLACE';

  @override
  String get jobsSearchHint => 'Search for matching projects...';

  @override
  String get jobsCategoryAll => 'All';

  @override
  String get jobsCategoryDesign => 'Design';

  @override
  String get jobsCategoryContent => 'Content';

  @override
  String get jobsCategoryVideo => 'Video';

  @override
  String get jobsCategoryPresentation => 'Presentation';

  @override
  String get jobsComingSoonTitle => 'Marketplace Coming Soon';

  @override
  String get jobsComingSoonDescription =>
      'You will be able to browse and apply for teacher projects here. The marketplace is currently under active development.';

  @override
  String get portfolioSubtitle => 'YOUR WORK';

  @override
  String get portfolioAdd => 'Add';

  @override
  String get portfolioStatsWorks => 'Works';

  @override
  String get portfolioStatsViewed => 'Viewed';

  @override
  String get portfolioStatsLiked => 'Liked';

  @override
  String get portfolioComingSoonTitle => 'Portfolio Coming Soon';

  @override
  String get portfolioComingSoonDescription =>
      'Showcase your best work, from learning materials and presentations to educational content, to attract teachers.';

  @override
  String get galleryLoadError => 'Failed to load gallery';

  @override
  String get galleryEmptyTitle => 'No materials in Gallery';

  @override
  String get galleryUntitled => 'Untitled';

  @override
  String get galleryCategoryMiscellaneous => 'Miscellaneous';

  @override
  String get galleryFilterTitle => 'Filter Materials';

  @override
  String get galleryFilterClearAll => 'Clear all';

  @override
  String get galleryFilterSearchHint => 'Search materials, tags, or topics...';

  @override
  String get galleryFilterSubject => 'SUBJECT';

  @override
  String get galleryFilterResourceType => 'RESOURCE TYPE';

  @override
  String get galleryFilterDateAdded => 'DATE ADDED';

  @override
  String get galleryFilterSubjectMath => 'Math';

  @override
  String get galleryFilterSubjectScience => 'Science';

  @override
  String get galleryFilterSubjectHistory => 'History';

  @override
  String get galleryFilterSubjectLiterature => 'Literature';

  @override
  String get galleryFilterSubjectArt => 'Art';

  @override
  String get galleryFilterSubjectGeography => 'Geography';

  @override
  String get galleryFilterTypePdfs => 'PDFs';

  @override
  String get galleryFilterTypeImages => 'Images';

  @override
  String get galleryFilterTypeWorksheets => 'Worksheets';

  @override
  String get galleryFilterTypeVideos => 'Videos';

  @override
  String get galleryFilterTypeLinks => 'Links';

  @override
  String get galleryFilterDateAnytime => 'Anytime';

  @override
  String get galleryFilterDatePastWeek => 'Past Week';

  @override
  String get galleryFilterDatePastMonth => 'Past Month';

  @override
  String get galleryFilterDatePastYear => 'Past Year';

  @override
  String galleryFilterShowResults(int count) {
    return 'Show $count Results';
  }

  @override
  String get helpCenterTitle => 'Help Center';

  @override
  String get helpHeadline => 'How can we help?';

  @override
  String get helpSearchHint => 'Search for articles, guides...';

  @override
  String get helpQuickHelpTitle => 'Quick Help';

  @override
  String get helpGettingStartedTitle => 'Getting Started';

  @override
  String get helpGettingStartedSubtitle => 'Learn the basics';

  @override
  String get helpUserGuideTitle => 'User Guide';

  @override
  String get helpUserGuideSubtitle => 'Detailed tutorials';

  @override
  String get helpPopularQuestionsTitle => 'Popular Questions';

  @override
  String get helpQuestionNewModule => 'How do I create a new module?';

  @override
  String get helpQuestionSyncSchoolData => 'Can I sync my school data?';

  @override
  String get helpQuestionShareMaterials =>
      'How do I share materials with students?';

  @override
  String get helpQuestionVerifiedInstructor =>
      'What is a verified instructor profile?';

  @override
  String get helpStillNeedHelpTitle => 'Still need help?';

  @override
  String get helpStillNeedHelpDescription =>
      'Our support team is available 24/7 to assist you with any issues.';

  @override
  String get helpContactSupport => 'Contact Support';

  @override
  String get projectSuccessTitle => 'Project Added Successfully!';

  @override
  String projectSuccessDescription(Object title) {
    return '\"$title\" has been successfully added to your educational materials. You can now start editing or sharing it with your students.';
  }

  @override
  String get projectSuccessProjectTitleLabel => 'PROJECT TITLE';

  @override
  String get projectSuccessNewBadge => 'NEW';

  @override
  String get projectSuccessModulesLabel => 'MODULES';

  @override
  String projectSuccessUnits(int count) {
    return '$count Units';
  }

  @override
  String get projectSuccessAccessLabel => 'ACCESS';

  @override
  String get projectSuccessGoToWorkspace => 'Go to Workspace';

  @override
  String get projectSuccessExploreMoreProjects => 'Explore More Projects';

  @override
  String get commonSaveChanges => 'Save Changes';

  @override
  String get commonDeleteAccount => 'Delete Account';

  @override
  String get commonChangePassword => 'Change Password';

  @override
  String get commonPrivacyPolicy => 'Privacy Policy';

  @override
  String get workspaceHeaderHeadline => 'Manage your work.';

  @override
  String get workspaceHeaderDescription =>
      'Manage curriculum materials, organize new lecture ideas, and keep your digital workspace in order.';

  @override
  String get workspaceFilterAll => 'All';

  @override
  String get workspaceFilterDrafts => 'Drafts';

  @override
  String get workspaceFilterPublished => 'Published';

  @override
  String get workspaceFilterStudentMaterials => 'Student Materials';

  @override
  String get workspaceMaterialsTitle => 'My Teaching Materials';

  @override
  String get workspaceViewGallery => 'View Gallery';

  @override
  String get workspaceLoadErrorFallback => 'Failed to load materials';

  @override
  String get workspaceEmptyTitle => 'No materials to display yet';

  @override
  String get workspaceEmptyDescription =>
      'Create a project first. Materials will appear here after the project is created.';

  @override
  String get workspaceFirstProjectCta => 'Create Your First Project';

  @override
  String get workspaceCreateNewModule => 'Create New Module';

  @override
  String get workspaceCreateNewModuleSubtitle =>
      'Start building your next masterpiece';

  @override
  String get workspaceDraftsTitle => 'Drafts & Ideas';

  @override
  String get workspaceDraftSampleOne =>
      'Compare the ecological impact of traditional vs modern farming in Java...';

  @override
  String get workspaceDraftSampleTwo =>
      'Vocabulary quiz for Semester 2 - Advanced Literature...';

  @override
  String get workspaceQuickCapture => 'Quick Capture';

  @override
  String get workspaceResourceLibraryTitle => 'Resource Library';

  @override
  String get workspaceResourceTemplates => 'Templates';

  @override
  String get workspaceResourceAssets => 'Assets';

  @override
  String get workspaceResourceLectures => 'Lectures';

  @override
  String get workspaceResourceUpload => 'Upload';

  @override
  String workspaceStorageFull(int percent) {
    return 'Storage $percent% full';
  }

  @override
  String workspaceFeatureLibraryTitle(Object label) {
    return '$label Library';
  }

  @override
  String workspaceFeatureLibraryDescription(Object label) {
    return 'The $label section of your Resource Library is currently under construction. Soon you will be able to manage all your educational assets in one place.';
  }

  @override
  String get workspaceFeatureCloudSync => 'Cloud Sync';

  @override
  String workspaceFeatureCloudSyncDescription(Object label) {
    return 'Access your $label from any device, anywhere.';
  }

  @override
  String get profileGuestSubtitle => 'You are currently browsing as a guest';

  @override
  String get profileJoinTeacherTitle => 'Join as Teacher';

  @override
  String get profileJoinTeacherSubtitle =>
      'Share your expertise and build your academic legacy.';

  @override
  String get profileJoinTeacherLabel => 'Opportunity';

  @override
  String get profileJoinTeacherCta => 'Get Started';

  @override
  String get profileTeacherRegistrationTitle => 'Teacher Registration';

  @override
  String get profileTeacherRegistrationDescription =>
      'Become an educator and start sharing your knowledge today.';

  @override
  String get profileTeacherRegistrationFeatureName => 'Teacher Ecosystem';

  @override
  String get profileTeacherRegistrationFeatureDescription =>
      'Access tools for course creation and student management.';

  @override
  String get profileJoinFreelancerTitle => 'Join as Freelancer';

  @override
  String get profileJoinFreelancerSubtitle =>
      'Work on your own terms with high-tier educational projects.';

  @override
  String get profileJoinFreelancerLabel => 'Flexibility';

  @override
  String get profileJoinFreelancerCta => 'Learn More';

  @override
  String get profileFreelancerPortalTitle => 'Freelancer Portal';

  @override
  String get profileFreelancerPortalDescription =>
      'Register as a freelancer to participate in educational projects.';

  @override
  String get profileFreelancerPortalFeatureName => 'Klass Freelance';

  @override
  String get profileFreelancerPortalFeatureDescription =>
      'Flexible work opportunities for experts.';

  @override
  String get profileReturnTitle => 'Return to your journey';

  @override
  String get profileReturnSubtitle =>
      'Access your curated classes and achievements.';

  @override
  String get profileQuote =>
      '\"Knowledge is a curated gallery of the mind; begin your exhibition today.\"';

  @override
  String get profileVerifiedBadge => 'VERIFIED';

  @override
  String get profileRoleTeacherBadge => 'TEACHER';

  @override
  String get profileRoleFreelancerBadge => 'FREELANCER';

  @override
  String get profileYearsInEducation => '12 Years in Education';

  @override
  String get profileClassDashboardTitle => 'Class Dashboard';

  @override
  String get profileClassDashboardDescription =>
      'The Class Dashboard is being refined to provide you with a comprehensive overview of your teaching performance and student engagement metrics.';

  @override
  String get profileClassDashboardFeatureName => 'Performance Analytics';

  @override
  String get profileClassDashboardFeatureDescription =>
      'Real-time data on class participation and curriculum progress.';

  @override
  String get profileStatsClassesTaught => 'Classes Taught';

  @override
  String get profileStatsActive => 'Active';

  @override
  String get profileStatsStudentCount => 'Student Count';

  @override
  String get profileStatsEnrolled => 'Enrolled';

  @override
  String get profileStatsCurriculumHours => 'Curriculum Hours';

  @override
  String get profileStatsHoursPerWeek => 'h/week';

  @override
  String get profileInstitutionalToolsTitle => 'Institutional Tools';

  @override
  String get profileToolGradebookAttendance => 'Gradebook &\nAttendance';

  @override
  String get profileToolCurriculumPlanner => 'Curriculum\nPlanner';

  @override
  String get profileToolSchoolAnnouncements => 'School\nAnnouncements';

  @override
  String get profileToolParentPortal => 'Parent\nPortal';

  @override
  String profileInstitutionalToolDescription(Object label) {
    return 'We are working on bringing $label directly to your mobile device for seamless institutional management.';
  }

  @override
  String get profileInstitutionalSyncFeatureName => 'Institutional Sync';

  @override
  String get profileInstitutionalSyncFeatureDescription =>
      'Stay connected with your school\'s management systems on the go.';

  @override
  String get profileTeachingMaterialsTitle => 'Curriculum Modules';

  @override
  String get profileTeachingMaterialsSubtitle =>
      'Manage and review your educational curriculum.';

  @override
  String get profileModuleOneTitle => 'Intro to Quantum Physics';

  @override
  String get profileModuleOneDescription =>
      'A comprehensive journey from classical mechanics to the mysteries of quantum entanglements.';

  @override
  String get profileModuleOneStats => '1.2k students · 14h';

  @override
  String get profileModuleTwoTitle => 'Modern Art History';

  @override
  String get profileModuleTwoDescription =>
      'Exploring the seismic shifts in artistic expression from the mid-19th century to today.';

  @override
  String get profileModuleTwoStats => '850 students · 8h';

  @override
  String get profileModuleThreeTitle => 'Advanced Thermodynamics';

  @override
  String get profileModuleThreeDescription =>
      'In-depth analysis of entropy, enthalpy, and energy conversion systems.';

  @override
  String get profileModuleThreeStats => '4/12 Modules';

  @override
  String get profileAccountSupportTitle => 'Account & Support';

  @override
  String get profileAccountSettings => 'Account Settings';

  @override
  String get profileHelpCenter => 'Help Center';

  @override
  String get profileRegisterFreelancer => 'Register as Freelancer';

  @override
  String get profileLogout => 'Logout';

  @override
  String get profileLogInCreateAccount => 'Log In / Create Account';

  @override
  String get profileFreelancerRegistrationTitle => 'Freelancer Registration';

  @override
  String get profileFreelancerRegistrationDescription =>
      'Our freelancer registration portal is currently under construction.';

  @override
  String get profileFreelancerRegistrationFeatureName => 'Become a Teacher';

  @override
  String get profileFreelancerRegistrationFeatureDescription =>
      'Share your curriculum and earn from your creations.';

  @override
  String get profileFreelancerProfileTitle => 'Freelancer Profile';

  @override
  String get profileSkillsTitle => 'Skills';

  @override
  String get profileSkillGraphicDesign => 'Graphic Design';

  @override
  String get profileSkillPresentation => 'Presentation';

  @override
  String get profileSkillVideoEditing => 'Video Editing';

  @override
  String get profileSkillEducationalContent => 'Educational Content';

  @override
  String get profileSkillsComingSoon => 'Edit Skills — Coming Soon';

  @override
  String get profilePortfolioStatsTitle => 'Portfolio Statistics';

  @override
  String get profilePortfolioStatsDescription =>
      'Performance metrics and reviews from teachers will appear here.';

  @override
  String get accountSettingsTitle => 'Account Settings';

  @override
  String get accountSettingsVerifiedTeacher => 'VERIFIED TEACHER';

  @override
  String get accountSettingsUserStudentRole => 'User / Student';

  @override
  String get accountSettingsPreviewPublicProfile => 'Preview Public Profile';

  @override
  String get accountSettingsPersonalInformation => 'Personal Information';

  @override
  String get accountSettingsShortBioLabel => 'SHORT BIO';

  @override
  String get accountSettingsNoBioProvided => 'No bio provided.';

  @override
  String get accountSettingsHintFullName => 'Enter your full name';

  @override
  String get accountSettingsHintEmailAddress => 'Enter your email address';

  @override
  String get accountSettingsHintShortBio => 'Tell people a bit about yourself';

  @override
  String get accountSettingsTeachingPreferences => 'Teaching Preferences';

  @override
  String get accountSettingsNotifications => 'Notifications';

  @override
  String get accountSettingsSecurity => 'Security';

  @override
  String get accountSettingsEmailNotificationsTitle => 'Email Notifications';

  @override
  String get accountSettingsEmailNotificationsSubtitle =>
      'Class alerts and messages';

  @override
  String get accountSettingsPushNotificationsTitle => 'Push Notifications';

  @override
  String get accountSettingsPushNotificationsSubtitle =>
      'Real-time mobile updates';

  @override
  String get accountSettingsWeeklyReportsTitle => 'Weekly Student Reports';

  @override
  String get accountSettingsWeeklyReportsSubtitle =>
      'Aggregated progress insights';

  @override
  String get accountSettingsSecuritySettingsTitle => 'Security Settings';

  @override
  String get accountSettingsSecuritySettingsDescription =>
      'We are enhancing our security features. You will soon be able to change your password, enable two-factor authentication, and manage active sessions.';

  @override
  String get accountSettingsSecuritySettingsFeatureName => 'Two-Factor Auth';

  @override
  String get accountSettingsSecuritySettingsFeatureDescription =>
      'Add an extra layer of protection to your account.';

  @override
  String get accountSettingsPrivacyLegalTitle => 'Privacy & Legal';

  @override
  String get accountSettingsPrivacyLegalDescription =>
      'Our legal team is finalizing the updated privacy policy and terms of service to ensure full compliance with the latest regulations.';

  @override
  String get accountSettingsPrivacyLegalFeatureName => 'Data Export';

  @override
  String get accountSettingsPrivacyLegalFeatureDescription =>
      'Download a complete copy of your personal data at any time.';

  @override
  String get accountSettingsAccountManagementTitle => 'Account Management';

  @override
  String get accountSettingsAccountManagementDescription =>
      'We are working on a streamlined process for account deletion and data archival to respect your right to be forgotten.';

  @override
  String get accountSettingsAccountManagementFeatureName => 'Data Archival';

  @override
  String get accountSettingsAccountManagementFeatureDescription =>
      'Archive your account instead of deleting it to preserve your work.';

  @override
  String get accountSettingsDeleteWarning =>
      'This action is permanent and will remove all your class materials and student data.';

  @override
  String get accountSettingsAvatarUpdatedSuccess =>
      'Avatar updated successfully';

  @override
  String accountSettingsAvatarUploadFailed(Object error) {
    return 'Failed to upload: $error';
  }
}
