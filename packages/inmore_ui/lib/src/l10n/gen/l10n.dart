import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_ar.dart';
import 'l10n_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
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
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

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
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Inmore'**
  String get appName;

  /// No description provided for @opsTagline.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get opsTagline;

  /// No description provided for @ownerTagline.
  ///
  /// In en, this message translates to:
  /// **'The business at a glance'**
  String get ownerTagline;

  /// No description provided for @brandLine.
  ///
  /// In en, this message translates to:
  /// **'Branding · Advertising · Packaging'**
  String get brandLine;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your Inmore account.'**
  String get signInSubtitle;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get enterEmail;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPassword;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'That email and password don\'t match.'**
  String get invalidCredentials;

  /// No description provided for @localDatabaseHint.
  ///
  /// In en, this message translates to:
  /// **'Local database. Dev accounts are listed in supabase/seed.sql.'**
  String get localDatabaseHint;

  /// No description provided for @accountInactive.
  ///
  /// In en, this message translates to:
  /// **'This account is not active yet. Ask the owner to activate it.'**
  String get accountInactive;

  /// No description provided for @accountProblemTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open your account'**
  String get accountProblemTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @copyDetails.
  ///
  /// In en, this message translates to:
  /// **'Copy details'**
  String get copyDetails;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @nobodyYet.
  ///
  /// In en, this message translates to:
  /// **'Nobody yet'**
  String get nobodyYet;

  /// No description provided for @unassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get unassigned;

  /// No description provided for @everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get everyone;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @errorOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get errorOfflineTitle;

  /// No description provided for @errorOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Check the network connection. This will refresh by itself when it\'s back.'**
  String get errorOfflineBody;

  /// No description provided for @errorTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'The server is taking too long'**
  String get errorTimeoutTitle;

  /// No description provided for @errorTimeoutBody.
  ///
  /// In en, this message translates to:
  /// **'It may be busy. Try again in a moment.'**
  String get errorTimeoutBody;

  /// No description provided for @errorPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get errorPermissionTitle;

  /// No description provided for @errorPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Your account doesn\'t have permission to do that.'**
  String get errorPermissionBody;

  /// No description provided for @errorNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get errorNotFoundTitle;

  /// No description provided for @errorNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'Someone may have cancelled or removed it.'**
  String get errorNotFoundBody;

  /// No description provided for @errorSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been signed out'**
  String get errorSessionTitle;

  /// No description provided for @errorSessionBody.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Sign in again to carry on.'**
  String get errorSessionBody;

  /// No description provided for @errorRefusedTitle.
  ///
  /// In en, this message translates to:
  /// **'That wasn\'t saved'**
  String get errorRefusedTitle;

  /// No description provided for @errorUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorUnknownTitle;

  /// No description provided for @errorUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'Try again. If it keeps happening, copy the details for whoever looks after the system.'**
  String get errorUnknownBody;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'No connection — showing what was last loaded'**
  String get offlineBanner;

  /// No description provided for @backOnline.
  ///
  /// In en, this message translates to:
  /// **'Back online'**
  String get backOnline;

  /// No description provided for @savedDataFrom.
  ///
  /// In en, this message translates to:
  /// **'Offline — showing data saved {time}'**
  String savedDataFrom(Object time);

  /// No description provided for @updatedAgo.
  ///
  /// In en, this message translates to:
  /// **'Updated {ago}'**
  String updatedAgo(Object ago);

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @agoFormat.
  ///
  /// In en, this message translates to:
  /// **'{duration} ago'**
  String agoFormat(Object duration);

  /// No description provided for @todayAt.
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String todayAt(Object time);

  /// No description provided for @yesterdayAt.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String yesterdayAt(Object time);

  /// No description provided for @durationDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String durationDays(int count);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String durationHours(int count);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String durationMinutes(int count);

  /// No description provided for @unsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this request?'**
  String get unsavedTitle;

  /// No description provided for @unsavedBody.
  ///
  /// In en, this message translates to:
  /// **'What you\'ve entered so far will be lost.'**
  String get unsavedBody;

  /// No description provided for @stageNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get stageNew;

  /// No description provided for @stageQuotation.
  ///
  /// In en, this message translates to:
  /// **'Quotation'**
  String get stageQuotation;

  /// No description provided for @stageDesign.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get stageDesign;

  /// No description provided for @stageCustomerApproval.
  ///
  /// In en, this message translates to:
  /// **'Customer approval'**
  String get stageCustomerApproval;

  /// No description provided for @stageProduction.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get stageProduction;

  /// No description provided for @stageDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get stageDelivery;

  /// No description provided for @stageCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get stageCompleted;

  /// No description provided for @stageCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get stageCancelled;

  /// No description provided for @waitingCustomer.
  ///
  /// In en, this message translates to:
  /// **'Waiting on customer'**
  String get waitingCustomer;

  /// No description provided for @waitingPayment.
  ///
  /// In en, this message translates to:
  /// **'Waiting on payment'**
  String get waitingPayment;

  /// No description provided for @waitingPartner.
  ///
  /// In en, this message translates to:
  /// **'Waiting on partner'**
  String get waitingPartner;

  /// No description provided for @waitingInternal.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get waitingInternal;

  /// No description provided for @sourceSupervisor.
  ///
  /// In en, this message translates to:
  /// **'Supervisor'**
  String get sourceSupervisor;

  /// No description provided for @sourceDesigner.
  ///
  /// In en, this message translates to:
  /// **'Designer'**
  String get sourceDesigner;

  /// No description provided for @sourceWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get sourceWebsite;

  /// No description provided for @sourceOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get sourceOther;

  /// No description provided for @itemPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get itemPending;

  /// No description provided for @itemApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get itemApproved;

  /// No description provided for @itemRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get itemRejected;

  /// No description provided for @itemCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get itemCancelled;

  /// No description provided for @fulfillmentUndecided.
  ///
  /// In en, this message translates to:
  /// **'Undecided'**
  String get fulfillmentUndecided;

  /// No description provided for @fulfillmentInternal.
  ///
  /// In en, this message translates to:
  /// **'In-house'**
  String get fulfillmentInternal;

  /// No description provided for @fulfillmentExternal.
  ///
  /// In en, this message translates to:
  /// **'External'**
  String get fulfillmentExternal;

  /// No description provided for @quoteDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get quoteDraft;

  /// No description provided for @quotePresented.
  ///
  /// In en, this message translates to:
  /// **'Presented'**
  String get quotePresented;

  /// No description provided for @quoteApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get quoteApproved;

  /// No description provided for @quoteRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get quoteRejected;

  /// No description provided for @quoteSuperseded.
  ///
  /// In en, this message translates to:
  /// **'Superseded'**
  String get quoteSuperseded;

  /// No description provided for @taskTypeDesign.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get taskTypeDesign;

  /// No description provided for @taskTypePrepress.
  ///
  /// In en, this message translates to:
  /// **'Prepress'**
  String get taskTypePrepress;

  /// No description provided for @taskTypeProduction.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get taskTypeProduction;

  /// No description provided for @taskTypeExternal.
  ///
  /// In en, this message translates to:
  /// **'External'**
  String get taskTypeExternal;

  /// No description provided for @taskTypeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get taskTypeDelivery;

  /// No description provided for @taskTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get taskTypeOther;

  /// No description provided for @taskTodo.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get taskTodo;

  /// No description provided for @taskInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get taskInProgress;

  /// No description provided for @taskBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get taskBlocked;

  /// No description provided for @taskDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskDone;

  /// No description provided for @taskCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get taskCancelled;

  /// No description provided for @taskDoingShort.
  ///
  /// In en, this message translates to:
  /// **'Doing'**
  String get taskDoingShort;

  /// No description provided for @methodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get methodCash;

  /// No description provided for @methodOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get methodOnline;

  /// No description provided for @methodBankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get methodBankTransfer;

  /// No description provided for @methodCheque.
  ///
  /// In en, this message translates to:
  /// **'Cheque'**
  String get methodCheque;

  /// No description provided for @kindDownPayment.
  ///
  /// In en, this message translates to:
  /// **'Down payment'**
  String get kindDownPayment;

  /// No description provided for @kindPartial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get kindPartial;

  /// No description provided for @kindFinal.
  ///
  /// In en, this message translates to:
  /// **'Final'**
  String get kindFinal;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// No description provided for @roleSupervisor.
  ///
  /// In en, this message translates to:
  /// **'Supervisor'**
  String get roleSupervisor;

  /// No description provided for @roleDesigner.
  ///
  /// In en, this message translates to:
  /// **'Designer'**
  String get roleDesigner;

  /// No description provided for @roleProduction.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get roleProduction;

  /// No description provided for @actRequestCreated.
  ///
  /// In en, this message translates to:
  /// **'Request created'**
  String get actRequestCreated;

  /// No description provided for @actStatusChanged.
  ///
  /// In en, this message translates to:
  /// **'Moved from {from} to {to}'**
  String actStatusChanged(Object from, Object to);

  /// No description provided for @actWaitingSet.
  ///
  /// In en, this message translates to:
  /// **'Blocked — {reason}'**
  String actWaitingSet(Object reason);

  /// No description provided for @actWaitingCleared.
  ///
  /// In en, this message translates to:
  /// **'Unblocked'**
  String get actWaitingCleared;

  /// No description provided for @actSupervisorChanged.
  ///
  /// In en, this message translates to:
  /// **'Supervisor changed'**
  String get actSupervisorChanged;

  /// No description provided for @actCompleted.
  ///
  /// In en, this message translates to:
  /// **'Request completed'**
  String get actCompleted;

  /// No description provided for @actCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled — {reason}'**
  String actCancelled(Object reason);

  /// No description provided for @actNoReason.
  ///
  /// In en, this message translates to:
  /// **'no reason given'**
  String get actNoReason;

  /// No description provided for @actReopened.
  ///
  /// In en, this message translates to:
  /// **'Reopened from {stage}'**
  String actReopened(Object stage);

  /// No description provided for @actItemAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {item}'**
  String actItemAdded(Object item);

  /// No description provided for @actItemRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed {item}'**
  String actItemRemoved(Object item);

  /// No description provided for @actItemDecision.
  ///
  /// In en, this message translates to:
  /// **'{item}: {decision}'**
  String actItemDecision(Object decision, Object item);

  /// No description provided for @actItemFallback.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get actItemFallback;

  /// No description provided for @actQuotationCreated.
  ///
  /// In en, this message translates to:
  /// **'Quotation v{version} drafted'**
  String actQuotationCreated(Object version);

  /// No description provided for @actQuotationPresented.
  ///
  /// In en, this message translates to:
  /// **'Quotation told to the customer'**
  String get actQuotationPresented;

  /// No description provided for @actQuotationApproved.
  ///
  /// In en, this message translates to:
  /// **'Customer approved the quotation'**
  String get actQuotationApproved;

  /// No description provided for @actQuotationRejected.
  ///
  /// In en, this message translates to:
  /// **'Customer rejected the quotation'**
  String get actQuotationRejected;

  /// No description provided for @actQuotationSuperseded.
  ///
  /// In en, this message translates to:
  /// **'Quotation replaced by a new version'**
  String get actQuotationSuperseded;

  /// No description provided for @actTaskCreated.
  ///
  /// In en, this message translates to:
  /// **'Work added: {title}'**
  String actTaskCreated(Object title);

  /// No description provided for @actTaskAssigned.
  ///
  /// In en, this message translates to:
  /// **'Work assigned'**
  String get actTaskAssigned;

  /// No description provided for @actTaskPartnerAssigned.
  ///
  /// In en, this message translates to:
  /// **'Sent to an external partner'**
  String get actTaskPartnerAssigned;

  /// No description provided for @actTaskStatusChanged.
  ///
  /// In en, this message translates to:
  /// **'Work marked {status}'**
  String actTaskStatusChanged(Object status);

  /// No description provided for @actTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Work finished'**
  String get actTaskCompleted;

  /// No description provided for @actTaskCost.
  ///
  /// In en, this message translates to:
  /// **'External cost recorded'**
  String get actTaskCost;

  /// No description provided for @actPaymentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payment received ({method})'**
  String actPaymentRecorded(Object method);

  /// No description provided for @actCustomerCreated.
  ///
  /// In en, this message translates to:
  /// **'Customer created'**
  String get actCustomerCreated;

  /// No description provided for @actCustomerUpdated.
  ///
  /// In en, this message translates to:
  /// **'Customer details updated'**
  String get actCustomerUpdated;

  /// No description provided for @navBoard.
  ///
  /// In en, this message translates to:
  /// **'Work board'**
  String get navBoard;

  /// No description provided for @navMyWork.
  ///
  /// In en, this message translates to:
  /// **'My work'**
  String get navMyWork;

  /// No description provided for @navCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get navCustomers;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @collapseSidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get collapseSidebar;

  /// No description provided for @expandSidebar.
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar'**
  String get expandSidebar;

  /// No description provided for @searchEverything.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchEverything;

  /// No description provided for @commandHint.
  ///
  /// In en, this message translates to:
  /// **'Jump to a request — number, customer or title'**
  String get commandHint;

  /// No description provided for @commandEmpty.
  ///
  /// In en, this message translates to:
  /// **'No requests match.'**
  String get commandEmpty;

  /// No description provided for @commandStart.
  ///
  /// In en, this message translates to:
  /// **'Type a request number like 1042, or part of a customer\'s name.'**
  String get commandStart;

  /// No description provided for @shortcutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get shortcutsTitle;

  /// No description provided for @shortcutSearch.
  ///
  /// In en, this message translates to:
  /// **'Find a request'**
  String get shortcutSearch;

  /// No description provided for @shortcutNewRequest.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get shortcutNewRequest;

  /// No description provided for @shortcutRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get shortcutRefresh;

  /// No description provided for @boardTitle.
  ///
  /// In en, this message translates to:
  /// **'Work board'**
  String get boardTitle;

  /// No description provided for @boardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing open right now} =1{1 open request} other{{count} open requests}}'**
  String boardSubtitle(int count);

  /// No description provided for @newRequest.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get newRequest;

  /// No description provided for @boardSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Customer, title, or #1042'**
  String get boardSearchHint;

  /// No description provided for @allStages.
  ///
  /// In en, this message translates to:
  /// **'All stages'**
  String get allStages;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @filterMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get filterMine;

  /// No description provided for @includeClosed.
  ///
  /// In en, this message translates to:
  /// **'Include closed'**
  String get includeClosed;

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttention;

  /// No description provided for @everythingElse.
  ///
  /// In en, this message translates to:
  /// **'Everything else'**
  String get everythingElse;

  /// No description provided for @colRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get colRequest;

  /// No description provided for @colStage.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get colStage;

  /// No description provided for @colSupervisor.
  ///
  /// In en, this message translates to:
  /// **'Supervisor'**
  String get colSupervisor;

  /// No description provided for @colItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get colItems;

  /// No description provided for @colDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get colDue;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get sortNewest;

  /// No description provided for @sortDue.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get sortDue;

  /// No description provided for @sortNumber.
  ///
  /// In en, this message translates to:
  /// **'Request number'**
  String get sortNumber;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortBy;

  /// No description provided for @noRequestsMatch.
  ///
  /// In en, this message translates to:
  /// **'No requests match'**
  String get noRequestsMatch;

  /// No description provided for @noRequestsMatchBody.
  ///
  /// In en, this message translates to:
  /// **'Try another stage or clear the search.'**
  String get noRequestsMatchBody;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @noRequestsYet.
  ///
  /// In en, this message translates to:
  /// **'No requests yet'**
  String get noRequestsYet;

  /// No description provided for @noRequestsYetBody.
  ///
  /// In en, this message translates to:
  /// **'New requests appear here the moment they\'re created.'**
  String get noRequestsYetBody;

  /// No description provided for @flagOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get flagOverdue;

  /// No description provided for @flagNoSupervisor.
  ///
  /// In en, this message translates to:
  /// **'No supervisor'**
  String get flagNoSupervisor;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} =1{1 item} other{{count} items}}'**
  String itemsCount(int count);

  /// No description provided for @dueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String dueOn(Object date);

  /// No description provided for @myWorkTitle.
  ///
  /// In en, this message translates to:
  /// **'My work'**
  String get myWorkTitle;

  /// No description provided for @myWorkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing open} =1{1 open task} other{{count} open tasks}}'**
  String myWorkSubtitle(int count);

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get allCaughtUp;

  /// No description provided for @allCaughtUpBody.
  ///
  /// In en, this message translates to:
  /// **'When a supervisor gives you work, it shows up here.'**
  String get allCaughtUpBody;

  /// No description provided for @openRequest.
  ///
  /// In en, this message translates to:
  /// **'Open request'**
  String get openRequest;

  /// No description provided for @customersTitle.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customersTitle;

  /// No description provided for @customersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find anyone by name, company or phone.'**
  String get customersSubtitle;

  /// No description provided for @newCustomer.
  ///
  /// In en, this message translates to:
  /// **'New customer'**
  String get newCustomer;

  /// No description provided for @editCustomer.
  ///
  /// In en, this message translates to:
  /// **'Edit customer'**
  String get editCustomer;

  /// No description provided for @customerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Name, company, or phone in any format'**
  String get customerSearchHint;

  /// No description provided for @phoneMatchHint.
  ///
  /// In en, this message translates to:
  /// **'Phone matching ignores spaces, dashes and the +974 prefix.'**
  String get phoneMatchHint;

  /// No description provided for @noCustomersFound.
  ///
  /// In en, this message translates to:
  /// **'No customers found'**
  String get noCustomersFound;

  /// No description provided for @noCustomersFoundBody.
  ///
  /// In en, this message translates to:
  /// **'Try another spelling, or add them as a new customer.'**
  String get noCustomersFoundBody;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get fieldPhone;

  /// No description provided for @fieldCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get fieldCompany;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @fieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get fieldNotes;

  /// No description provided for @duplicatePhone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Already used by {names}} other{Already used by {count} customers: {names}}}'**
  String duplicatePhone(int count, String names);

  /// No description provided for @customerSaved.
  ///
  /// In en, this message translates to:
  /// **'Customer saved'**
  String get customerSaved;

  /// No description provided for @newRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get newRequestTitle;

  /// No description provided for @newRequestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One request can hold every product the customer asked for.'**
  String get newRequestSubtitle;

  /// No description provided for @sectionCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get sectionCustomer;

  /// No description provided for @sectionRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get sectionRequest;

  /// No description provided for @sectionProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get sectionProducts;

  /// No description provided for @productsHint.
  ///
  /// In en, this message translates to:
  /// **'As many as the customer asked for'**
  String get productsHint;

  /// No description provided for @fieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldTitle;

  /// No description provided for @titleHint.
  ///
  /// In en, this message translates to:
  /// **'Cafe opening pack'**
  String get titleHint;

  /// No description provided for @fieldNeededBy.
  ///
  /// In en, this message translates to:
  /// **'Needed by'**
  String get fieldNeededBy;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'What the customer actually said'**
  String get notesHint;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get addProduct;

  /// No description provided for @noProductsYet.
  ///
  /// In en, this message translates to:
  /// **'No products yet. You can save without them — the detail can come later.'**
  String get noProductsYet;

  /// No description provided for @createRequest.
  ///
  /// In en, this message translates to:
  /// **'Create request'**
  String get createRequest;

  /// No description provided for @requestCreated.
  ///
  /// In en, this message translates to:
  /// **'Request #{number} created'**
  String requestCreated(int number);

  /// No description provided for @findCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'Find a customer by name, company or phone'**
  String get findCustomerHint;

  /// No description provided for @noMatchCreateFirst.
  ///
  /// In en, this message translates to:
  /// **'No match. Add them as a new customer.'**
  String get noMatchCreateFirst;

  /// No description provided for @fromCatalog.
  ///
  /// In en, this message translates to:
  /// **'From the catalog'**
  String get fromCatalog;

  /// No description provided for @somethingElse.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get somethingElse;

  /// No description provided for @fieldProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get fieldProduct;

  /// No description provided for @productHint.
  ///
  /// In en, this message translates to:
  /// **'500 custom printed boxes'**
  String get productHint;

  /// No description provided for @fieldQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get fieldQuantity;

  /// No description provided for @enterQuantity.
  ///
  /// In en, this message translates to:
  /// **'Enter a quantity'**
  String get enterQuantity;

  /// No description provided for @fieldUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get fieldUnit;

  /// No description provided for @unitHint.
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get unitHint;

  /// No description provided for @fieldSpec.
  ///
  /// In en, this message translates to:
  /// **'Spec'**
  String get fieldSpec;

  /// No description provided for @specHint.
  ///
  /// In en, this message translates to:
  /// **'Size, colours, material, finishing'**
  String get specHint;

  /// No description provided for @chooseCustomerFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a customer to continue'**
  String get chooseCustomerFirst;

  /// No description provided for @requestFrom.
  ///
  /// In en, this message translates to:
  /// **'Came in via {source}'**
  String requestFrom(Object source);

  /// No description provided for @stage.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get stage;

  /// No description provided for @blockedOn.
  ///
  /// In en, this message translates to:
  /// **'Blocked on'**
  String get blockedOn;

  /// No description provided for @notBlocked.
  ///
  /// In en, this message translates to:
  /// **'Moving'**
  String get notBlocked;

  /// No description provided for @cancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get cancelRequest;

  /// No description provided for @cancelRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel {reference}?'**
  String cancelRequestTitle(Object reference);

  /// No description provided for @cancelReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Why?'**
  String get cancelReasonLabel;

  /// No description provided for @cancelReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Customer went elsewhere'**
  String get cancelReasonHint;

  /// No description provided for @cancelReasonHelp.
  ///
  /// In en, this message translates to:
  /// **'Required. Months from now this is the only record of why.'**
  String get cancelReasonHelp;

  /// No description provided for @keepIt.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get keepIt;

  /// No description provided for @requestCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled'**
  String get requestCancelled;

  /// No description provided for @movedTo.
  ///
  /// In en, this message translates to:
  /// **'Moved to {stage}'**
  String movedTo(Object stage);

  /// No description provided for @supervisor.
  ///
  /// In en, this message translates to:
  /// **'Supervisor'**
  String get supervisor;

  /// No description provided for @supervisorUpdated.
  ///
  /// In en, this message translates to:
  /// **'Supervisor updated'**
  String get supervisorUpdated;

  /// No description provided for @neededBy.
  ///
  /// In en, this message translates to:
  /// **'Needed by'**
  String get neededBy;

  /// No description provided for @created.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get created;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @moneyTitle.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get moneyTitle;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @paidInAdvance.
  ///
  /// In en, this message translates to:
  /// **'Paid in advance — nothing has been approved yet, so there\'s no balance.'**
  String get paidInAdvance;

  /// No description provided for @noApprovedQuotation.
  ///
  /// In en, this message translates to:
  /// **'No approved quotation yet.'**
  String get noApprovedQuotation;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available.'**
  String get notAvailable;

  /// No description provided for @productsTitle.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get productsTitle;

  /// No description provided for @nothingListed.
  ///
  /// In en, this message translates to:
  /// **'Nothing listed yet.'**
  String get nothingListed;

  /// No description provided for @itemRemoved.
  ///
  /// In en, this message translates to:
  /// **'Product removed'**
  String get itemRemoved;

  /// No description provided for @removeItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {item}?'**
  String removeItemTitle(Object item);

  /// No description provided for @removeItemBody.
  ///
  /// In en, this message translates to:
  /// **'The removal is kept in the history.'**
  String get removeItemBody;

  /// No description provided for @workTitle.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get workTitle;

  /// No description provided for @assignWork.
  ///
  /// In en, this message translates to:
  /// **'Assign work'**
  String get assignWork;

  /// No description provided for @addMyTask.
  ///
  /// In en, this message translates to:
  /// **'Add my task'**
  String get addMyTask;

  /// No description provided for @nobodyOnThis.
  ///
  /// In en, this message translates to:
  /// **'Nobody is on this yet.'**
  String get nobodyOnThis;

  /// No description provided for @externalName.
  ///
  /// In en, this message translates to:
  /// **'{name} · external'**
  String externalName(Object name);

  /// No description provided for @whatNeedsDoing.
  ///
  /// In en, this message translates to:
  /// **'What needs doing'**
  String get whatNeedsDoing;

  /// No description provided for @taskTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Cup artwork'**
  String get taskTitleHint;

  /// No description provided for @kindOfWork.
  ///
  /// In en, this message translates to:
  /// **'Kind of work'**
  String get kindOfWork;

  /// No description provided for @forWhichProduct.
  ///
  /// In en, this message translates to:
  /// **'For which product'**
  String get forWhichProduct;

  /// No description provided for @wholeRequest.
  ///
  /// In en, this message translates to:
  /// **'The whole request'**
  String get wholeRequest;

  /// No description provided for @externalPartner.
  ///
  /// In en, this message translates to:
  /// **'Going to an external partner'**
  String get externalPartner;

  /// No description provided for @partner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get partner;

  /// No description provided for @who.
  ///
  /// In en, this message translates to:
  /// **'Who'**
  String get who;

  /// No description provided for @assignedToYou.
  ///
  /// In en, this message translates to:
  /// **'This will be assigned to you.'**
  String get assignedToYou;

  /// No description provided for @workAdded.
  ///
  /// In en, this message translates to:
  /// **'Work added'**
  String get workAdded;

  /// No description provided for @took.
  ///
  /// In en, this message translates to:
  /// **'Took {duration}'**
  String took(Object duration);

  /// No description provided for @quotationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quotations'**
  String get quotationsTitle;

  /// No description provided for @quotationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Spoken, not sent — this records what was said'**
  String get quotationsSubtitle;

  /// No description provided for @priceTheWork.
  ///
  /// In en, this message translates to:
  /// **'Price the work'**
  String get priceTheWork;

  /// No description provided for @nothingPriced.
  ///
  /// In en, this message translates to:
  /// **'Nothing priced yet.'**
  String get nothingPriced;

  /// No description provided for @toldCustomer.
  ///
  /// In en, this message translates to:
  /// **'Told the customer'**
  String get toldCustomer;

  /// No description provided for @markApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get markApproved;

  /// No description provided for @markRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get markRejected;

  /// No description provided for @revise.
  ///
  /// In en, this message translates to:
  /// **'Revise'**
  String get revise;

  /// No description provided for @afterDiscount.
  ///
  /// In en, this message translates to:
  /// **'after {amount} off'**
  String afterDiscount(Object amount);

  /// No description provided for @presentedOn.
  ///
  /// In en, this message translates to:
  /// **'Presented {date}'**
  String presentedOn(Object date);

  /// No description provided for @draftOn.
  ///
  /// In en, this message translates to:
  /// **'Draft · {date}'**
  String draftOn(Object date);

  /// No description provided for @markedStatus.
  ///
  /// In en, this message translates to:
  /// **'Marked {status}'**
  String markedStatus(Object status);

  /// No description provided for @addProductBeforePricing.
  ///
  /// In en, this message translates to:
  /// **'Add a product to the request before pricing it.'**
  String get addProductBeforePricing;

  /// No description provided for @reviseTitle.
  ///
  /// In en, this message translates to:
  /// **'Revise v{version}'**
  String reviseTitle(int version);

  /// No description provided for @leaveBlank.
  ///
  /// In en, this message translates to:
  /// **'Leave a product blank to quote it separately later.'**
  String get leaveBlank;

  /// No description provided for @unitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get unitPrice;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @previewNote.
  ///
  /// In en, this message translates to:
  /// **'The database recalculates this when it saves — what you see is a preview.'**
  String get previewNote;

  /// No description provided for @createVersion.
  ///
  /// In en, this message translates to:
  /// **'Create v{version}'**
  String createVersion(int version);

  /// No description provided for @quotationSaved.
  ///
  /// In en, this message translates to:
  /// **'Quotation saved'**
  String get quotationSaved;

  /// No description provided for @priceAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Put a price on at least one product.'**
  String get priceAtLeastOne;

  /// No description provided for @approveTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer approved {version}?'**
  String approveTitle(Object version);

  /// No description provided for @approveBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} becomes the agreed price. Changing it later means a new version.'**
  String approveBody(Object amount);

  /// No description provided for @rejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer rejected {version}?'**
  String rejectTitle(Object version);

  /// No description provided for @rejectBody.
  ///
  /// In en, this message translates to:
  /// **'You can revise it into a new version afterwards.'**
  String get rejectBody;

  /// No description provided for @paymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get paymentsTitle;

  /// No description provided for @recordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get recordPayment;

  /// No description provided for @nothingReceived.
  ///
  /// In en, this message translates to:
  /// **'Nothing received yet.'**
  String get nothingReceived;

  /// No description provided for @paymentsImmutable.
  ///
  /// In en, this message translates to:
  /// **'Payments can\'t be edited or deleted. A mistake is corrected by recording the opposite.'**
  String get paymentsImmutable;

  /// No description provided for @recordPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Record a payment'**
  String get recordPaymentTitle;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @how.
  ///
  /// In en, this message translates to:
  /// **'How'**
  String get how;

  /// No description provided for @whatItIs.
  ///
  /// In en, this message translates to:
  /// **'What it is'**
  String get whatItIs;

  /// No description provided for @paymentKindHelp.
  ///
  /// In en, this message translates to:
  /// **'A label only — whether the job is settled is worked out from the total.'**
  String get paymentKindHelp;

  /// No description provided for @reference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get reference;

  /// No description provided for @referenceHint.
  ///
  /// In en, this message translates to:
  /// **'Receipt or transfer number'**
  String get referenceHint;

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get record;

  /// No description provided for @enterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount.'**
  String get enterAmount;

  /// No description provided for @paymentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get paymentRecorded;

  /// No description provided for @confirmPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Record {amount}?'**
  String confirmPaymentTitle(Object amount);

  /// No description provided for @confirmPaymentBody.
  ///
  /// In en, this message translates to:
  /// **'{method} · {kind}. Payments can\'t be edited or deleted afterwards.'**
  String confirmPaymentBody(Object kind, Object method);

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @nothingRecorded.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet.'**
  String get nothingRecorded;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @reportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export requests and their products to Excel.'**
  String get reportsSubtitle;

  /// No description provided for @whatToInclude.
  ///
  /// In en, this message translates to:
  /// **'What to include'**
  String get whatToInclude;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get dateRange;

  /// No description provided for @everything.
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get everything;

  /// No description provided for @whatYouGet.
  ///
  /// In en, this message translates to:
  /// **'What you get'**
  String get whatYouGet;

  /// No description provided for @reportItemsSheet.
  ///
  /// In en, this message translates to:
  /// **'Items — one row per product, the way the current sheet already reads. Line totals sum correctly here.'**
  String get reportItemsSheet;

  /// No description provided for @reportRequestsSheet.
  ///
  /// In en, this message translates to:
  /// **'Requests — one row per request. The totals live here and only here, so summing a column gives the real figure.'**
  String get reportRequestsSheet;

  /// No description provided for @reportFormatNote.
  ///
  /// In en, this message translates to:
  /// **'Dates are real Excel dates, money is a number with two decimals, and phone numbers stay text so the leading zero survives. The workbook is always in English, so it reads the same for everyone.'**
  String get reportFormatNote;

  /// No description provided for @createWorkbook.
  ///
  /// In en, this message translates to:
  /// **'Create the workbook'**
  String get createWorkbook;

  /// No description provided for @workbookSaved.
  ///
  /// In en, this message translates to:
  /// **'Workbook saved'**
  String get workbookSaved;

  /// No description provided for @showInFolder.
  ///
  /// In en, this message translates to:
  /// **'Show in folder'**
  String get showInFolder;

  /// No description provided for @nothingMatchesFilters.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches those filters.'**
  String get nothingMatchesFilters;

  /// No description provided for @workbookFailed.
  ///
  /// In en, this message translates to:
  /// **'The workbook could not be written.'**
  String get workbookFailed;

  /// No description provided for @exportSummary.
  ///
  /// In en, this message translates to:
  /// **'{items} item rows · {requests} requests'**
  String exportSummary(int items, int requests);

  /// No description provided for @tabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get tabOverview;

  /// No description provided for @tabAttention.
  ///
  /// In en, this message translates to:
  /// **'Attention'**
  String get tabAttention;

  /// No description provided for @tabMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get tabMoney;

  /// No description provided for @tabPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get tabPeople;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String greetingMorning(Object name);

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}'**
  String greetingAfternoon(Object name);

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String greetingEvening(Object name);

  /// No description provided for @openJobs.
  ///
  /// In en, this message translates to:
  /// **'Open jobs'**
  String get openJobs;

  /// No description provided for @cameInThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Came in this week'**
  String get cameInThisWeek;

  /// No description provided for @finishedThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Finished this week'**
  String get finishedThisWeek;

  /// No description provided for @blocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blocked;

  /// No description provided for @pastDue.
  ///
  /// In en, this message translates to:
  /// **'Past due'**
  String get pastDue;

  /// No description provided for @whereWorkSits.
  ///
  /// In en, this message translates to:
  /// **'Where the work sits'**
  String get whereWorkSits;

  /// No description provided for @latest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest;

  /// No description provided for @nothingOpen.
  ///
  /// In en, this message translates to:
  /// **'Nothing open.'**
  String get nothingOpen;

  /// No description provided for @attentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get attentionTitle;

  /// No description provided for @attentionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} open jobs'**
  String attentionSubtitle(int count, int total);

  /// No description provided for @nothingStuck.
  ///
  /// In en, this message translates to:
  /// **'Nothing is stuck'**
  String get nothingStuck;

  /// No description provided for @nothingStuckBody.
  ///
  /// In en, this message translates to:
  /// **'Everything open is moving.'**
  String get nothingStuckBody;

  /// No description provided for @pastPromisedDate.
  ///
  /// In en, this message translates to:
  /// **'Past the promised date'**
  String get pastPromisedDate;

  /// No description provided for @nobodyPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Nobody has picked these up'**
  String get nobodyPickedUp;

  /// No description provided for @acrossEveryRequest.
  ///
  /// In en, this message translates to:
  /// **'Across every request'**
  String get acrossEveryRequest;

  /// No description provided for @stillOwing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing owed} =1{1 request still owing} other{{count} requests still owing}}'**
  String stillOwing(int count);

  /// No description provided for @approvedInTotal.
  ///
  /// In en, this message translates to:
  /// **'Approved in total'**
  String get approvedInTotal;

  /// No description provided for @received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// No description provided for @moneyNote.
  ///
  /// In en, this message translates to:
  /// **'Only jobs with an approved quotation count towards what\'s owed. A down payment taken before pricing shows under Received and nowhere else.'**
  String get moneyNote;

  /// No description provided for @waitingOnPayment.
  ///
  /// In en, this message translates to:
  /// **'Waiting on payment'**
  String get waitingOnPayment;

  /// No description provided for @noneOnPayment.
  ///
  /// In en, this message translates to:
  /// **'No job is held up on payment.'**
  String get noneOnPayment;

  /// No description provided for @peopleTitle.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get peopleTitle;

  /// No description provided for @peopleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open work, busiest first'**
  String get peopleSubtitle;

  /// No description provided for @noOpenWork.
  ///
  /// In en, this message translates to:
  /// **'No open work assigned to anyone.'**
  String get noOpenWork;

  /// No description provided for @openCount.
  ///
  /// In en, this message translates to:
  /// **'{count} open'**
  String openCount(int count);

  /// No description provided for @inProgressCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in progress'**
  String inProgressCount(int count);

  /// No description provided for @lateCount.
  ///
  /// In en, this message translates to:
  /// **'{count} late'**
  String lateCount(int count);

  /// No description provided for @whatTheyAskedFor.
  ///
  /// In en, this message translates to:
  /// **'What they asked for'**
  String get whatTheyAskedFor;

  /// No description provided for @whoIsOnIt.
  ///
  /// In en, this message translates to:
  /// **'Who is on it'**
  String get whoIsOnIt;

  /// No description provided for @whatHappened.
  ///
  /// In en, this message translates to:
  /// **'What happened'**
  String get whatHappened;

  /// No description provided for @stillOwed.
  ///
  /// In en, this message translates to:
  /// **'Still owed'**
  String get stillOwed;

  /// No description provided for @opened.
  ///
  /// In en, this message translates to:
  /// **'Opened'**
  String get opened;

  /// No description provided for @nobodyAssigned.
  ///
  /// In en, this message translates to:
  /// **'Nobody assigned'**
  String get nobodyAssigned;

  /// No description provided for @paidInAdvanceAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} paid in advance. Nothing has been approved yet, so there\'s no balance.'**
  String paidInAdvanceAmount(Object amount);
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return L10nAr();
    case 'en':
      return L10nEn();
  }

  throw FlutterError(
      'L10n.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
