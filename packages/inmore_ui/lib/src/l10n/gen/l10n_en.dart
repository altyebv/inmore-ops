// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Inmore';

  @override
  String get opsTagline => 'Operations';

  @override
  String get ownerTagline => 'The business at a glance';

  @override
  String get brandLine => 'Branding · Advertising · Packaging';

  @override
  String get signIn => 'Sign in';

  @override
  String get signInTitle => 'Welcome back';

  @override
  String get signInSubtitle => 'Sign in with your Inmore account.';

  @override
  String get signOut => 'Sign out';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get enterEmail => 'Enter your email address';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get invalidCredentials => 'That email and password don\'t match.';

  @override
  String get localDatabaseHint =>
      'Local database. Dev accounts are listed in supabase/seed.sql.';

  @override
  String get accountInactive =>
      'This account is not active yet. Ask the owner to activate it.';

  @override
  String get accountProblemTitle => 'Can\'t open your account';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get add => 'Add';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Try again';

  @override
  String get refresh => 'Refresh';

  @override
  String get change => 'Change';

  @override
  String get clear => 'Clear';

  @override
  String get remove => 'Remove';

  @override
  String get discard => 'Discard';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get copyDetails => 'Copy details';

  @override
  String get copied => 'Copied';

  @override
  String get required => 'Required';

  @override
  String get optional => 'Optional';

  @override
  String get notSet => 'Not set';

  @override
  String get nobodyYet => 'Nobody yet';

  @override
  String get unassigned => 'Unassigned';

  @override
  String get everyone => 'Everyone';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get errorOfflineTitle => 'You\'re offline';

  @override
  String get errorOfflineBody =>
      'Check the network connection. This will refresh by itself when it\'s back.';

  @override
  String get errorTimeoutTitle => 'The server is taking too long';

  @override
  String get errorTimeoutBody => 'It may be busy. Try again in a moment.';

  @override
  String get errorPermissionTitle => 'Not allowed';

  @override
  String get errorPermissionBody =>
      'Your account doesn\'t have permission to do that.';

  @override
  String get errorNotFoundTitle => 'Not found';

  @override
  String get errorNotFoundBody => 'Someone may have cancelled or removed it.';

  @override
  String get errorSessionTitle => 'You\'ve been signed out';

  @override
  String get errorSessionBody =>
      'Your session ended. Sign in again to carry on.';

  @override
  String get errorRefusedTitle => 'That wasn\'t saved';

  @override
  String get errorUnknownTitle => 'Something went wrong';

  @override
  String get errorUnknownBody =>
      'Try again. If it keeps happening, copy the details for whoever looks after the system.';

  @override
  String get offlineBanner => 'No connection — showing what was last loaded';

  @override
  String get backOnline => 'Back online';

  @override
  String savedDataFrom(Object time) {
    return 'Offline — showing data saved $time';
  }

  @override
  String updatedAgo(Object ago) {
    return 'Updated $ago';
  }

  @override
  String get justNow => 'just now';

  @override
  String agoFormat(Object duration) {
    return '$duration ago';
  }

  @override
  String todayAt(Object time) {
    return 'Today, $time';
  }

  @override
  String yesterdayAt(Object time) {
    return 'Yesterday, $time';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    return '${count}h';
  }

  @override
  String durationMinutes(int count) {
    return '${count}m';
  }

  @override
  String get unsavedTitle => 'Discard this request?';

  @override
  String get unsavedBody => 'What you\'ve entered so far will be lost.';

  @override
  String get stageNew => 'New';

  @override
  String get stageQuotation => 'Quotation';

  @override
  String get stageDesign => 'Design';

  @override
  String get stageCustomerApproval => 'Customer approval';

  @override
  String get stageProduction => 'Production';

  @override
  String get stageDelivery => 'Delivery';

  @override
  String get stageCompleted => 'Completed';

  @override
  String get stageCancelled => 'Cancelled';

  @override
  String get waitingCustomer => 'Waiting on customer';

  @override
  String get waitingPayment => 'Waiting on payment';

  @override
  String get waitingPartner => 'Waiting on partner';

  @override
  String get waitingInternal => 'On hold';

  @override
  String get sourceSupervisor => 'Supervisor';

  @override
  String get sourceDesigner => 'Designer';

  @override
  String get sourceWebsite => 'Website';

  @override
  String get sourceOther => 'Other';

  @override
  String get itemPending => 'Pending';

  @override
  String get itemApproved => 'Approved';

  @override
  String get itemRejected => 'Rejected';

  @override
  String get itemCancelled => 'Cancelled';

  @override
  String get fulfillmentUndecided => 'Undecided';

  @override
  String get fulfillmentInternal => 'In-house';

  @override
  String get fulfillmentExternal => 'External';

  @override
  String get quoteDraft => 'Draft';

  @override
  String get quotePresented => 'Presented';

  @override
  String get quoteApproved => 'Approved';

  @override
  String get quoteRejected => 'Rejected';

  @override
  String get quoteSuperseded => 'Superseded';

  @override
  String get taskTypeDesign => 'Design';

  @override
  String get taskTypePrepress => 'Prepress';

  @override
  String get taskTypeProduction => 'Production';

  @override
  String get taskTypeExternal => 'External';

  @override
  String get taskTypeDelivery => 'Delivery';

  @override
  String get taskTypeOther => 'Other';

  @override
  String get taskTodo => 'To do';

  @override
  String get taskInProgress => 'In progress';

  @override
  String get taskBlocked => 'Blocked';

  @override
  String get taskDone => 'Done';

  @override
  String get taskCancelled => 'Cancelled';

  @override
  String get taskDoingShort => 'Doing';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodOnline => 'Online';

  @override
  String get methodBankTransfer => 'Bank transfer';

  @override
  String get methodCheque => 'Cheque';

  @override
  String get kindDownPayment => 'Down payment';

  @override
  String get kindPartial => 'Partial';

  @override
  String get kindFinal => 'Final';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleSupervisor => 'Supervisor';

  @override
  String get roleDesigner => 'Designer';

  @override
  String get roleProduction => 'Production';

  @override
  String get actRequestCreated => 'Request created';

  @override
  String actStatusChanged(Object from, Object to) {
    return 'Moved from $from to $to';
  }

  @override
  String actWaitingSet(Object reason) {
    return 'Blocked — $reason';
  }

  @override
  String get actWaitingCleared => 'Unblocked';

  @override
  String get actSupervisorChanged => 'Supervisor changed';

  @override
  String get actCompleted => 'Request completed';

  @override
  String actCancelled(Object reason) {
    return 'Request cancelled — $reason';
  }

  @override
  String get actNoReason => 'no reason given';

  @override
  String actReopened(Object stage) {
    return 'Reopened from $stage';
  }

  @override
  String actItemAdded(Object item) {
    return 'Added $item';
  }

  @override
  String actItemRemoved(Object item) {
    return 'Removed $item';
  }

  @override
  String actItemDecision(Object decision, Object item) {
    return '$item: $decision';
  }

  @override
  String get actItemFallback => 'Product';

  @override
  String actQuotationCreated(Object version) {
    return 'Quotation v$version drafted';
  }

  @override
  String get actQuotationPresented => 'Quotation told to the customer';

  @override
  String get actQuotationApproved => 'Customer approved the quotation';

  @override
  String get actQuotationRejected => 'Customer rejected the quotation';

  @override
  String get actQuotationSuperseded => 'Quotation replaced by a new version';

  @override
  String actTaskCreated(Object title) {
    return 'Work added: $title';
  }

  @override
  String get actTaskAssigned => 'Work assigned';

  @override
  String get actTaskPartnerAssigned => 'Sent to an external partner';

  @override
  String actTaskStatusChanged(Object status) {
    return 'Work marked $status';
  }

  @override
  String get actTaskCompleted => 'Work finished';

  @override
  String get actTaskCost => 'External cost recorded';

  @override
  String actPaymentRecorded(Object method) {
    return 'Payment received ($method)';
  }

  @override
  String get actCustomerCreated => 'Customer created';

  @override
  String get actCustomerUpdated => 'Customer details updated';

  @override
  String get navBoard => 'Work board';

  @override
  String get navMyWork => 'My work';

  @override
  String get navCustomers => 'Customers';

  @override
  String get navReports => 'Reports';

  @override
  String get collapseSidebar => 'Collapse sidebar';

  @override
  String get expandSidebar => 'Expand sidebar';

  @override
  String get searchEverything => 'Search';

  @override
  String get commandHint => 'Jump to a request — number, customer or title';

  @override
  String get commandEmpty => 'No requests match.';

  @override
  String get commandStart =>
      'Type a request number like 1042, or part of a customer\'s name.';

  @override
  String get shortcutsTitle => 'Keyboard shortcuts';

  @override
  String get shortcutSearch => 'Find a request';

  @override
  String get shortcutNewRequest => 'New request';

  @override
  String get shortcutRefresh => 'Refresh';

  @override
  String get boardTitle => 'Work board';

  @override
  String boardSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open requests',
      one: '1 open request',
      zero: 'Nothing open right now',
    );
    return '$_temp0';
  }

  @override
  String get newRequest => 'New request';

  @override
  String get boardSearchHint => 'Customer, title, or #1042';

  @override
  String get allStages => 'All stages';

  @override
  String get all => 'All';

  @override
  String get filterMine => 'Mine';

  @override
  String get includeClosed => 'Include closed';

  @override
  String get needsAttention => 'Needs attention';

  @override
  String get everythingElse => 'Everything else';

  @override
  String get colRequest => 'Request';

  @override
  String get colStage => 'Stage';

  @override
  String get colSupervisor => 'Supervisor';

  @override
  String get colItems => 'Items';

  @override
  String get colDue => 'Due';

  @override
  String get sortNewest => 'Newest first';

  @override
  String get sortDue => 'Due date';

  @override
  String get sortNumber => 'Request number';

  @override
  String get sortBy => 'Sort';

  @override
  String get noRequestsMatch => 'No requests match';

  @override
  String get noRequestsMatchBody => 'Try another stage or clear the search.';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get noRequestsYet => 'No requests yet';

  @override
  String get noRequestsYetBody =>
      'New requests appear here the moment they\'re created.';

  @override
  String get flagOverdue => 'Overdue';

  @override
  String get flagNoSupervisor => 'No supervisor';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String dueOn(Object date) {
    return 'Due $date';
  }

  @override
  String get myWorkTitle => 'My work';

  @override
  String myWorkSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open tasks',
      one: '1 open task',
      zero: 'Nothing open',
    );
    return '$_temp0';
  }

  @override
  String get allCaughtUp => 'You\'re all caught up';

  @override
  String get allCaughtUpBody =>
      'When a supervisor gives you work, it shows up here.';

  @override
  String get openRequest => 'Open request';

  @override
  String get customersTitle => 'Customers';

  @override
  String get customersSubtitle => 'Find anyone by name, company or phone.';

  @override
  String get newCustomer => 'New customer';

  @override
  String get editCustomer => 'Edit customer';

  @override
  String get customerSearchHint => 'Name, company, or phone in any format';

  @override
  String get phoneMatchHint =>
      'Phone matching ignores spaces, dashes and the +974 prefix.';

  @override
  String get noCustomersFound => 'No customers found';

  @override
  String get noCustomersFoundBody =>
      'Try another spelling, or add them as a new customer.';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldPhone => 'Phone';

  @override
  String get fieldCompany => 'Company';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldNotes => 'Notes';

  @override
  String duplicatePhone(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Already used by $count customers: $names',
      one: 'Already used by $names',
    );
    return '$_temp0';
  }

  @override
  String get customerSaved => 'Customer saved';

  @override
  String get newRequestTitle => 'New request';

  @override
  String get newRequestSubtitle =>
      'One request can hold every product the customer asked for.';

  @override
  String get sectionCustomer => 'Customer';

  @override
  String get sectionRequest => 'Request';

  @override
  String get sectionProducts => 'Products';

  @override
  String get productsHint => 'As many as the customer asked for';

  @override
  String get fieldTitle => 'Title';

  @override
  String get titleHint => 'Cafe opening pack';

  @override
  String get fieldNeededBy => 'Needed by';

  @override
  String get notesHint => 'What the customer actually said';

  @override
  String get addProduct => 'Add product';

  @override
  String get noProductsYet =>
      'No products yet. You can save without them — the detail can come later.';

  @override
  String get createRequest => 'Create request';

  @override
  String requestCreated(int number) {
    return 'Request #$number created';
  }

  @override
  String get findCustomerHint => 'Find a customer by name, company or phone';

  @override
  String get noMatchCreateFirst => 'No match. Add them as a new customer.';

  @override
  String get fromCatalog => 'From the catalog';

  @override
  String get somethingElse => 'Something else';

  @override
  String get fieldProduct => 'Product';

  @override
  String get productHint => '500 custom printed boxes';

  @override
  String get fieldQuantity => 'Quantity';

  @override
  String get enterQuantity => 'Enter a quantity';

  @override
  String get fieldUnit => 'Unit';

  @override
  String get unitHint => 'pcs';

  @override
  String get fieldSpec => 'Spec';

  @override
  String get specHint => 'Size, colours, material, finishing';

  @override
  String get chooseCustomerFirst => 'Choose a customer to continue';

  @override
  String requestFrom(Object source) {
    return 'Came in via $source';
  }

  @override
  String get stage => 'Stage';

  @override
  String get blockedOn => 'Blocked on';

  @override
  String get notBlocked => 'Moving';

  @override
  String get cancelRequest => 'Cancel request';

  @override
  String cancelRequestTitle(Object reference) {
    return 'Cancel $reference?';
  }

  @override
  String get cancelReasonLabel => 'Why?';

  @override
  String get cancelReasonHint => 'Customer went elsewhere';

  @override
  String get cancelReasonHelp =>
      'Required. Months from now this is the only record of why.';

  @override
  String get keepIt => 'Keep it';

  @override
  String get requestCancelled => 'Request cancelled';

  @override
  String movedTo(Object stage) {
    return 'Moved to $stage';
  }

  @override
  String get supervisor => 'Supervisor';

  @override
  String get supervisorUpdated => 'Supervisor updated';

  @override
  String get neededBy => 'Needed by';

  @override
  String get created => 'Created';

  @override
  String get customer => 'Customer';

  @override
  String get phone => 'Phone';

  @override
  String get source => 'Source';

  @override
  String get details => 'Details';

  @override
  String get moneyTitle => 'Money';

  @override
  String get approved => 'Approved';

  @override
  String get paid => 'Paid';

  @override
  String get balance => 'Balance';

  @override
  String get paidInAdvance =>
      'Paid in advance — nothing has been approved yet, so there\'s no balance.';

  @override
  String get noApprovedQuotation => 'No approved quotation yet.';

  @override
  String get notAvailable => 'Not available.';

  @override
  String get productsTitle => 'Products';

  @override
  String get nothingListed => 'Nothing listed yet.';

  @override
  String get itemRemoved => 'Product removed';

  @override
  String removeItemTitle(Object item) {
    return 'Remove $item?';
  }

  @override
  String get removeItemBody => 'The removal is kept in the history.';

  @override
  String get workTitle => 'Work';

  @override
  String get assignWork => 'Assign work';

  @override
  String get addMyTask => 'Add my task';

  @override
  String get nobodyOnThis => 'Nobody is on this yet.';

  @override
  String externalName(Object name) {
    return '$name · external';
  }

  @override
  String get whatNeedsDoing => 'What needs doing';

  @override
  String get taskTitleHint => 'Cup artwork';

  @override
  String get kindOfWork => 'Kind of work';

  @override
  String get forWhichProduct => 'For which product';

  @override
  String get wholeRequest => 'The whole request';

  @override
  String get externalPartner => 'Going to an external partner';

  @override
  String get partner => 'Partner';

  @override
  String get who => 'Who';

  @override
  String get assignedToYou => 'This will be assigned to you.';

  @override
  String get workAdded => 'Work added';

  @override
  String took(Object duration) {
    return 'Took $duration';
  }

  @override
  String get quotationsTitle => 'Quotations';

  @override
  String get quotationsSubtitle =>
      'Spoken, not sent — this records what was said';

  @override
  String get priceTheWork => 'Price the work';

  @override
  String get nothingPriced => 'Nothing priced yet.';

  @override
  String get toldCustomer => 'Told the customer';

  @override
  String get markApproved => 'Approved';

  @override
  String get markRejected => 'Rejected';

  @override
  String get revise => 'Revise';

  @override
  String afterDiscount(Object amount) {
    return 'after $amount off';
  }

  @override
  String presentedOn(Object date) {
    return 'Presented $date';
  }

  @override
  String draftOn(Object date) {
    return 'Draft · $date';
  }

  @override
  String markedStatus(Object status) {
    return 'Marked $status';
  }

  @override
  String get addProductBeforePricing =>
      'Add a product to the request before pricing it.';

  @override
  String reviseTitle(int version) {
    return 'Revise v$version';
  }

  @override
  String get leaveBlank =>
      'Leave a product blank to quote it separately later.';

  @override
  String get unitPrice => 'Unit price';

  @override
  String get discount => 'Discount';

  @override
  String get total => 'Total';

  @override
  String get previewNote =>
      'The database recalculates this when it saves — what you see is a preview.';

  @override
  String createVersion(int version) {
    return 'Create v$version';
  }

  @override
  String get quotationSaved => 'Quotation saved';

  @override
  String get priceAtLeastOne => 'Put a price on at least one product.';

  @override
  String approveTitle(Object version) {
    return 'Customer approved $version?';
  }

  @override
  String approveBody(Object amount) {
    return '$amount becomes the agreed price. Changing it later means a new version.';
  }

  @override
  String rejectTitle(Object version) {
    return 'Customer rejected $version?';
  }

  @override
  String get rejectBody => 'You can revise it into a new version afterwards.';

  @override
  String get paymentsTitle => 'Payments';

  @override
  String get recordPayment => 'Record payment';

  @override
  String get nothingReceived => 'Nothing received yet.';

  @override
  String get paymentsImmutable =>
      'Payments can\'t be edited or deleted. A mistake is corrected by recording the opposite.';

  @override
  String get recordPaymentTitle => 'Record a payment';

  @override
  String get amount => 'Amount';

  @override
  String get how => 'How';

  @override
  String get whatItIs => 'What it is';

  @override
  String get paymentKindHelp =>
      'A label only — whether the job is settled is worked out from the total.';

  @override
  String get reference => 'Reference';

  @override
  String get referenceHint => 'Receipt or transfer number';

  @override
  String get record => 'Record';

  @override
  String get enterAmount => 'Enter an amount.';

  @override
  String get paymentRecorded => 'Payment recorded';

  @override
  String confirmPaymentTitle(Object amount) {
    return 'Record $amount?';
  }

  @override
  String confirmPaymentBody(Object kind, Object method) {
    return '$method · $kind. Payments can\'t be edited or deleted afterwards.';
  }

  @override
  String get historyTitle => 'History';

  @override
  String get nothingRecorded => 'Nothing recorded yet.';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsSubtitle => 'Export requests and their products to Excel.';

  @override
  String get whatToInclude => 'What to include';

  @override
  String get dateRange => 'Date range';

  @override
  String get everything => 'Everything';

  @override
  String get whatYouGet => 'What you get';

  @override
  String get reportItemsSheet =>
      'Items — one row per product, the way the current sheet already reads. Line totals sum correctly here.';

  @override
  String get reportRequestsSheet =>
      'Requests — one row per request. The totals live here and only here, so summing a column gives the real figure.';

  @override
  String get reportFormatNote =>
      'Dates are real Excel dates, money is a number with two decimals, and phone numbers stay text so the leading zero survives. The workbook is always in English, so it reads the same for everyone.';

  @override
  String get createWorkbook => 'Create the workbook';

  @override
  String get workbookSaved => 'Workbook saved';

  @override
  String get showInFolder => 'Show in folder';

  @override
  String get nothingMatchesFilters => 'Nothing matches those filters.';

  @override
  String get workbookFailed => 'The workbook could not be written.';

  @override
  String exportSummary(int items, int requests) {
    return '$items item rows · $requests requests';
  }

  @override
  String get tabOverview => 'Overview';

  @override
  String get tabAttention => 'Attention';

  @override
  String get tabMoney => 'Money';

  @override
  String get tabPeople => 'People';

  @override
  String greetingMorning(Object name) {
    return 'Good morning, $name';
  }

  @override
  String greetingAfternoon(Object name) {
    return 'Good afternoon, $name';
  }

  @override
  String greetingEvening(Object name) {
    return 'Good evening, $name';
  }

  @override
  String get openJobs => 'Open jobs';

  @override
  String get cameInThisWeek => 'Came in this week';

  @override
  String get finishedThisWeek => 'Finished this week';

  @override
  String get blocked => 'Blocked';

  @override
  String get pastDue => 'Past due';

  @override
  String get whereWorkSits => 'Where the work sits';

  @override
  String get latest => 'Latest';

  @override
  String get nothingOpen => 'Nothing open.';

  @override
  String get attentionTitle => 'Needs attention';

  @override
  String attentionSubtitle(int count, int total) {
    return '$count of $total open jobs';
  }

  @override
  String get nothingStuck => 'Nothing is stuck';

  @override
  String get nothingStuckBody => 'Everything open is moving.';

  @override
  String get pastPromisedDate => 'Past the promised date';

  @override
  String get nobodyPickedUp => 'Nobody has picked these up';

  @override
  String get acrossEveryRequest => 'Across every request';

  @override
  String stillOwing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests still owing',
      one: '1 request still owing',
      zero: 'Nothing owed',
    );
    return '$_temp0';
  }

  @override
  String get approvedInTotal => 'Approved in total';

  @override
  String get received => 'Received';

  @override
  String get moneyNote =>
      'Only jobs with an approved quotation count towards what\'s owed. A down payment taken before pricing shows under Received and nowhere else.';

  @override
  String get waitingOnPayment => 'Waiting on payment';

  @override
  String get noneOnPayment => 'No job is held up on payment.';

  @override
  String get peopleTitle => 'People';

  @override
  String get peopleSubtitle => 'Open work, busiest first';

  @override
  String get noOpenWork => 'No open work assigned to anyone.';

  @override
  String openCount(int count) {
    return '$count open';
  }

  @override
  String inProgressCount(int count) {
    return '$count in progress';
  }

  @override
  String lateCount(int count) {
    return '$count late';
  }

  @override
  String get whatTheyAskedFor => 'What they asked for';

  @override
  String get whoIsOnIt => 'Who is on it';

  @override
  String get whatHappened => 'What happened';

  @override
  String get stillOwed => 'Still owed';

  @override
  String get opened => 'Opened';

  @override
  String get nobodyAssigned => 'Nobody assigned';

  @override
  String paidInAdvanceAmount(Object amount) {
    return '$amount paid in advance. Nothing has been approved yet, so there\'s no balance.';
  }
}
