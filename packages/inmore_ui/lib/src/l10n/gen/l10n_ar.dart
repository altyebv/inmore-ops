// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class L10nAr extends L10n {
  L10nAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'إنمور';

  @override
  String get opsTagline => 'العمليات';

  @override
  String get ownerTagline => 'نظرة شاملة على العمل';

  @override
  String get brandLine => 'هوية تجارية · إعلان · تغليف';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signInTitle => 'أهلًا بعودتك';

  @override
  String get signInSubtitle => 'سجّل الدخول بحساب إنمور الخاص بك.';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get enterEmail => 'أدخل بريدك الإلكتروني';

  @override
  String get enterPassword => 'أدخل كلمة المرور';

  @override
  String get invalidCredentials =>
      'البريد الإلكتروني وكلمة المرور غير متطابقين.';

  @override
  String get localDatabaseHint =>
      'قاعدة بيانات محلية. حسابات التطوير مذكورة في supabase/seed.sql.';

  @override
  String get accountInactive =>
      'هذا الحساب غير مفعّل بعد. اطلب من المالك تفعيله.';

  @override
  String get accountProblemTitle => 'تعذّر فتح حسابك';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get create => 'إنشاء';

  @override
  String get add => 'إضافة';

  @override
  String get close => 'إغلاق';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get refresh => 'تحديث';

  @override
  String get change => 'تغيير';

  @override
  String get clear => 'مسح';

  @override
  String get remove => 'إزالة';

  @override
  String get discard => 'تجاهل';

  @override
  String get keepEditing => 'متابعة التعديل';

  @override
  String get copyDetails => 'نسخ التفاصيل';

  @override
  String get copied => 'تم النسخ';

  @override
  String get required => 'مطلوب';

  @override
  String get optional => 'اختياري';

  @override
  String get notSet => 'غير محدد';

  @override
  String get nobodyYet => 'لا أحد بعد';

  @override
  String get unassigned => 'غير مُسند';

  @override
  String get everyone => 'الجميع';

  @override
  String get settings => 'الإعدادات';

  @override
  String get appearance => 'المظهر';

  @override
  String get themeSystem => 'النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get language => 'اللغة';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get errorOfflineTitle => 'لا يوجد اتصال';

  @override
  String get errorOfflineBody =>
      'تحقق من اتصال الشبكة. سيتم التحديث تلقائيًا عند عودته.';

  @override
  String get errorTimeoutTitle => 'الخادم يستغرق وقتًا طويلًا';

  @override
  String get errorTimeoutBody => 'قد يكون مشغولًا. حاول مرة أخرى بعد قليل.';

  @override
  String get errorPermissionTitle => 'غير مسموح';

  @override
  String get errorPermissionBody => 'حسابك لا يملك صلاحية القيام بذلك.';

  @override
  String get errorNotFoundTitle => 'غير موجود';

  @override
  String get errorNotFoundBody => 'ربما ألغاه أو أزاله شخص آخر.';

  @override
  String get errorSessionTitle => 'تم تسجيل خروجك';

  @override
  String get errorSessionBody => 'انتهت جلستك. سجّل الدخول مجددًا للمتابعة.';

  @override
  String get errorRefusedTitle => 'لم يتم الحفظ';

  @override
  String get errorUnknownTitle => 'حدث خطأ ما';

  @override
  String get errorUnknownBody =>
      'حاول مرة أخرى. إذا تكرر الأمر، انسخ التفاصيل وأرسلها للمسؤول عن النظام.';

  @override
  String get offlineBanner => 'لا يوجد اتصال — يتم عرض آخر بيانات محمّلة';

  @override
  String get backOnline => 'عاد الاتصال';

  @override
  String savedDataFrom(Object time) {
    return 'غير متصل — بيانات محفوظة $time';
  }

  @override
  String updatedAgo(Object ago) {
    return 'آخر تحديث $ago';
  }

  @override
  String get justNow => 'الآن';

  @override
  String agoFormat(Object duration) {
    return 'منذ $duration';
  }

  @override
  String todayAt(Object time) {
    return 'اليوم، $time';
  }

  @override
  String yesterdayAt(Object time) {
    return 'أمس، $time';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    return '$count س';
  }

  @override
  String durationMinutes(int count) {
    return '$count د';
  }

  @override
  String get unsavedTitle => 'تجاهل هذا الطلب؟';

  @override
  String get unsavedBody => 'سيضيع كل ما أدخلته حتى الآن.';

  @override
  String get stageNew => 'جديد';

  @override
  String get stageQuotation => 'عرض السعر';

  @override
  String get stageDesign => 'التصميم';

  @override
  String get stageCustomerApproval => 'موافقة العميل';

  @override
  String get stageProduction => 'الإنتاج';

  @override
  String get stageDelivery => 'التسليم';

  @override
  String get stageCompleted => 'مكتمل';

  @override
  String get stageCancelled => 'ملغى';

  @override
  String get waitingCustomer => 'بانتظار العميل';

  @override
  String get waitingPayment => 'بانتظار الدفع';

  @override
  String get waitingPartner => 'بانتظار الشريك';

  @override
  String get waitingInternal => 'معلّق';

  @override
  String get sourceSupervisor => 'مشرف';

  @override
  String get sourceDesigner => 'مصمم';

  @override
  String get sourceWebsite => 'الموقع الإلكتروني';

  @override
  String get sourceOther => 'أخرى';

  @override
  String get itemPending => 'قيد الانتظار';

  @override
  String get itemApproved => 'موافق عليه';

  @override
  String get itemRejected => 'مرفوض';

  @override
  String get itemCancelled => 'ملغى';

  @override
  String get fulfillmentUndecided => 'لم يُحدد';

  @override
  String get fulfillmentInternal => 'داخلي';

  @override
  String get fulfillmentExternal => 'خارجي';

  @override
  String get quoteDraft => 'مسودة';

  @override
  String get quotePresented => 'مُقدَّم';

  @override
  String get quoteApproved => 'معتمد';

  @override
  String get quoteRejected => 'مرفوض';

  @override
  String get quoteSuperseded => 'مُستبدل';

  @override
  String get taskTypeDesign => 'تصميم';

  @override
  String get taskTypePrepress => 'ما قبل الطباعة';

  @override
  String get taskTypeProduction => 'إنتاج';

  @override
  String get taskTypeExternal => 'خارجي';

  @override
  String get taskTypeDelivery => 'توصيل';

  @override
  String get taskTypeOther => 'أخرى';

  @override
  String get taskTodo => 'لم يبدأ';

  @override
  String get taskInProgress => 'قيد التنفيذ';

  @override
  String get taskBlocked => 'متوقف';

  @override
  String get taskDone => 'منجز';

  @override
  String get taskCancelled => 'ملغى';

  @override
  String get taskDoingShort => 'جارٍ';

  @override
  String get methodCash => 'نقدًا';

  @override
  String get methodOnline => 'إلكتروني';

  @override
  String get methodBankTransfer => 'تحويل بنكي';

  @override
  String get methodCheque => 'شيك';

  @override
  String get kindDownPayment => 'دفعة مقدمة';

  @override
  String get kindPartial => 'دفعة جزئية';

  @override
  String get kindFinal => 'دفعة نهائية';

  @override
  String get roleOwner => 'المالك';

  @override
  String get roleSupervisor => 'مشرف';

  @override
  String get roleDesigner => 'مصمم';

  @override
  String get roleProduction => 'إنتاج';

  @override
  String get actRequestCreated => 'تم إنشاء الطلب';

  @override
  String actStatusChanged(Object from, Object to) {
    return 'انتقل من $from إلى $to';
  }

  @override
  String actWaitingSet(Object reason) {
    return 'متوقف — $reason';
  }

  @override
  String get actWaitingCleared => 'استُؤنف العمل';

  @override
  String get actSupervisorChanged => 'تم تغيير المشرف';

  @override
  String get actCompleted => 'اكتمل الطلب';

  @override
  String actCancelled(Object reason) {
    return 'أُلغي الطلب — $reason';
  }

  @override
  String get actNoReason => 'بدون سبب';

  @override
  String actReopened(Object stage) {
    return 'أُعيد فتحه من $stage';
  }

  @override
  String actItemAdded(Object item) {
    return 'أُضيف $item';
  }

  @override
  String actItemRemoved(Object item) {
    return 'أُزيل $item';
  }

  @override
  String actItemDecision(Object decision, Object item) {
    return '$item: $decision';
  }

  @override
  String get actItemFallback => 'منتج';

  @override
  String actQuotationCreated(Object version) {
    return 'مسودة عرض السعر v$version';
  }

  @override
  String get actQuotationPresented => 'أُبلغ العميل بعرض السعر';

  @override
  String get actQuotationApproved => 'وافق العميل على عرض السعر';

  @override
  String get actQuotationRejected => 'رفض العميل عرض السعر';

  @override
  String get actQuotationSuperseded => 'استُبدل عرض السعر بنسخة جديدة';

  @override
  String actTaskCreated(Object title) {
    return 'أُضيف عمل: $title';
  }

  @override
  String get actTaskAssigned => 'أُسند العمل';

  @override
  String get actTaskPartnerAssigned => 'أُرسل إلى شريك خارجي';

  @override
  String actTaskStatusChanged(Object status) {
    return 'أصبح العمل: $status';
  }

  @override
  String get actTaskCompleted => 'انتهى العمل';

  @override
  String get actTaskCost => 'سُجّلت تكلفة خارجية';

  @override
  String actPaymentRecorded(Object method) {
    return 'استُلمت دفعة ($method)';
  }

  @override
  String get actCustomerCreated => 'تم إنشاء العميل';

  @override
  String get actCustomerUpdated => 'تم تحديث بيانات العميل';

  @override
  String get navBoard => 'لوحة العمل';

  @override
  String get navMyWork => 'مهامي';

  @override
  String get navCustomers => 'العملاء';

  @override
  String get navReports => 'التقارير';

  @override
  String get collapseSidebar => 'طي الشريط الجانبي';

  @override
  String get expandSidebar => 'توسيع الشريط الجانبي';

  @override
  String get searchEverything => 'بحث';

  @override
  String get commandHint => 'انتقل إلى طلب — بالرقم أو اسم العميل أو العنوان';

  @override
  String get commandEmpty => 'لا توجد طلبات مطابقة.';

  @override
  String get commandStart => 'اكتب رقم طلب مثل 1042، أو جزءًا من اسم العميل.';

  @override
  String get shortcutsTitle => 'اختصارات لوحة المفاتيح';

  @override
  String get shortcutSearch => 'البحث عن طلب';

  @override
  String get shortcutNewRequest => 'طلب جديد';

  @override
  String get shortcutRefresh => 'تحديث';

  @override
  String get shortcutHelp => 'المساعدة';

  @override
  String get boardTitle => 'لوحة العمل';

  @override
  String boardSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طلب مفتوح',
      many: '$count طلبًا مفتوحًا',
      few: '$count طلبات مفتوحة',
      two: 'طلبان مفتوحان',
      one: 'طلب واحد مفتوح',
      zero: 'لا يوجد شيء مفتوح الآن',
    );
    return '$_temp0';
  }

  @override
  String get newRequest => 'طلب جديد';

  @override
  String get boardSearchHint => 'العميل، العنوان، أو ‎#1042';

  @override
  String get allStages => 'كل المراحل';

  @override
  String get all => 'الكل';

  @override
  String get filterMine => 'طلباتي';

  @override
  String get includeClosed => 'إظهار المغلقة';

  @override
  String get needsAttention => 'يحتاج إلى متابعة';

  @override
  String get everythingElse => 'البقية';

  @override
  String get colRequest => 'الطلب';

  @override
  String get colStage => 'المرحلة';

  @override
  String get colSupervisor => 'المشرف';

  @override
  String get colItems => 'المنتجات';

  @override
  String get colDue => 'الموعد';

  @override
  String get sortNewest => 'الأحدث أولًا';

  @override
  String get sortDue => 'تاريخ الاستحقاق';

  @override
  String get sortNumber => 'رقم الطلب';

  @override
  String get sortBy => 'ترتيب';

  @override
  String get noRequestsMatch => 'لا توجد طلبات مطابقة';

  @override
  String get noRequestsMatchBody => 'جرّب مرحلة أخرى أو امسح البحث.';

  @override
  String get clearFilters => 'مسح عوامل التصفية';

  @override
  String get noRequestsYet => 'لا توجد طلبات بعد';

  @override
  String get noRequestsYetBody => 'تظهر الطلبات الجديدة هنا فور إنشائها.';

  @override
  String get flagOverdue => 'متأخر';

  @override
  String get flagNoSupervisor => 'بلا مشرف';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منتج',
      many: '$count منتجًا',
      few: '$count منتجات',
      two: 'منتجان',
      one: 'منتج واحد',
      zero: 'لا منتجات',
    );
    return '$_temp0';
  }

  @override
  String dueOn(Object date) {
    return 'الموعد $date';
  }

  @override
  String get myWorkTitle => 'مهامي';

  @override
  String myWorkSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مهمة مفتوحة',
      many: '$count مهمة مفتوحة',
      few: '$count مهام مفتوحة',
      two: 'مهمتان مفتوحتان',
      one: 'مهمة واحدة مفتوحة',
      zero: 'لا شيء مفتوح',
    );
    return '$_temp0';
  }

  @override
  String get allCaughtUp => 'لا يوجد ما ينتظرك';

  @override
  String get allCaughtUpBody => 'عندما يسند إليك المشرف عملًا، سيظهر هنا.';

  @override
  String get openRequest => 'فتح الطلب';

  @override
  String get customersTitle => 'العملاء';

  @override
  String get customersSubtitle => 'ابحث بالاسم أو الشركة أو رقم الهاتف.';

  @override
  String get newCustomer => 'عميل جديد';

  @override
  String get editCustomer => 'تعديل العميل';

  @override
  String get customerSearchHint => 'الاسم أو الشركة أو الهاتف بأي صيغة';

  @override
  String get noCustomersFound => 'لا يوجد عملاء مطابقون';

  @override
  String get noCustomersFoundBody => 'جرّب تهجئة أخرى، أو أضفه كعميل جديد.';

  @override
  String get fieldName => 'الاسم';

  @override
  String get fieldPhone => 'الهاتف';

  @override
  String get fieldCompany => 'الشركة';

  @override
  String get fieldEmail => 'البريد الإلكتروني';

  @override
  String get fieldNotes => 'ملاحظات';

  @override
  String duplicatePhone(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مستخدم بالفعل لدى $count عميل: $names',
      many: 'مستخدم بالفعل لدى $count عميلًا: $names',
      few: 'مستخدم بالفعل لدى $count عملاء: $names',
      two: 'مستخدم بالفعل لدى عميلين: $names',
      one: 'مستخدم بالفعل لدى $names',
    );
    return '$_temp0';
  }

  @override
  String get customerSaved => 'تم حفظ العميل';

  @override
  String get newRequestTitle => 'طلب جديد';

  @override
  String get newRequestSubtitle =>
      'يمكن للطلب الواحد أن يضم كل المنتجات التي طلبها العميل.';

  @override
  String get sectionCustomer => 'العميل';

  @override
  String get sectionRequest => 'الطلب';

  @override
  String get sectionProducts => 'المنتجات';

  @override
  String get productsHint => 'بقدر ما طلب العميل';

  @override
  String get fieldTitle => 'العنوان';

  @override
  String get titleHint => 'باقة افتتاح المقهى';

  @override
  String get fieldNeededBy => 'مطلوب بتاريخ';

  @override
  String get notesHint => 'ما قاله العميل فعلًا';

  @override
  String get addProduct => 'إضافة منتج';

  @override
  String get noProductsYet =>
      'لا منتجات بعد. أضفها هنا، أو لاحقًا من صفحة الطلب.';

  @override
  String get createRequest => 'إنشاء الطلب';

  @override
  String requestCreated(int number) {
    return 'تم إنشاء الطلب ‎#$number';
  }

  @override
  String get findCustomerHint => 'ابحث عن عميل بالاسم أو الشركة أو الهاتف';

  @override
  String get noMatchCreateFirst => 'لا نتائج. أضفه كعميل جديد.';

  @override
  String get fromCatalog => 'من الكتالوج';

  @override
  String get somethingElse => 'شيء آخر';

  @override
  String get fieldProduct => 'المنتج';

  @override
  String get productHint => '500 علبة مطبوعة حسب الطلب';

  @override
  String get fieldQuantity => 'الكمية';

  @override
  String get enterQuantity => 'أدخل الكمية';

  @override
  String get fieldUnit => 'الوحدة';

  @override
  String get unitHint => 'قطعة';

  @override
  String get fieldSpec => 'المواصفات';

  @override
  String get specHint => 'المقاس، الألوان، الخامة، التشطيب';

  @override
  String get chooseCustomerFirst => 'اختر عميلًا للمتابعة';

  @override
  String requestFrom(Object source) {
    return 'ورد عبر: $source';
  }

  @override
  String get stage => 'المرحلة';

  @override
  String get blockedOn => 'متوقف بسبب';

  @override
  String get notBlocked => 'يسير';

  @override
  String get cancelRequest => 'إلغاء الطلب';

  @override
  String cancelRequestTitle(Object reference) {
    return 'إلغاء $reference؟';
  }

  @override
  String get cancelReasonLabel => 'لماذا؟';

  @override
  String get cancelReasonHint => 'العميل ذهب إلى جهة أخرى';

  @override
  String get cancelReasonHelp => 'مطلوب. يُحفظ في سجل الطلب.';

  @override
  String get keepIt => 'الإبقاء عليه';

  @override
  String get requestCancelled => 'تم إلغاء الطلب';

  @override
  String movedTo(Object stage) {
    return 'نُقل إلى $stage';
  }

  @override
  String get supervisor => 'المشرف';

  @override
  String get supervisorUpdated => 'تم تحديث المشرف';

  @override
  String get neededBy => 'مطلوب بتاريخ';

  @override
  String get created => 'تاريخ الإنشاء';

  @override
  String get customer => 'العميل';

  @override
  String get phone => 'الهاتف';

  @override
  String get source => 'المصدر';

  @override
  String get details => 'التفاصيل';

  @override
  String get moneyTitle => 'المال';

  @override
  String get approved => 'المعتمد';

  @override
  String get paid => 'المدفوع';

  @override
  String get balance => 'المتبقي';

  @override
  String get paidInAdvance =>
      'دُفع مقدمًا — لم يُعتمد شيء بعد، لذلك لا يوجد رصيد.';

  @override
  String get noApprovedQuotation => 'لا يوجد عرض سعر معتمد بعد.';

  @override
  String get notAvailable => 'غير متاح.';

  @override
  String get productsTitle => 'المنتجات';

  @override
  String get nothingListed => 'لم يُدرج شيء بعد.';

  @override
  String get itemRemoved => 'تمت إزالة المنتج';

  @override
  String removeItemTitle(Object item) {
    return 'إزالة $item؟';
  }

  @override
  String get removeItemBody => 'ستبقى الإزالة مسجلة في السجل.';

  @override
  String get workTitle => 'الأعمال';

  @override
  String get assignWork => 'إسناد عمل';

  @override
  String get addMyTask => 'إضافة مهمة لي';

  @override
  String get nobodyOnThis => 'لا أحد يعمل على هذا بعد.';

  @override
  String externalName(Object name) {
    return '$name · خارجي';
  }

  @override
  String get whatNeedsDoing => 'ما المطلوب';

  @override
  String get taskTitleHint => 'تصميم الأكواب';

  @override
  String get kindOfWork => 'نوع العمل';

  @override
  String get forWhichProduct => 'لأي منتج';

  @override
  String get wholeRequest => 'الطلب بالكامل';

  @override
  String get externalPartner => 'يُرسل إلى شريك خارجي';

  @override
  String get partner => 'الشريك';

  @override
  String get who => 'من';

  @override
  String get assignedToYou => 'سيُسند هذا إليك.';

  @override
  String get workAdded => 'تمت إضافة العمل';

  @override
  String took(Object duration) {
    return 'استغرق $duration';
  }

  @override
  String get quotationsTitle => 'عروض الأسعار';

  @override
  String get priceTheWork => 'تسعير العمل';

  @override
  String get nothingPriced => 'لم يُسعّر شيء بعد.';

  @override
  String get toldCustomer => 'أُبلغ العميل';

  @override
  String get markApproved => 'وافق';

  @override
  String get markRejected => 'رفض';

  @override
  String get revise => 'مراجعة';

  @override
  String afterDiscount(Object amount) {
    return 'بعد خصم $amount';
  }

  @override
  String presentedOn(Object date) {
    return 'قُدّم $date';
  }

  @override
  String draftOn(Object date) {
    return 'مسودة · $date';
  }

  @override
  String markedStatus(Object status) {
    return 'أصبح: $status';
  }

  @override
  String get addProductBeforePricing => 'أضف منتجًا إلى الطلب قبل تسعيره.';

  @override
  String reviseTitle(int version) {
    return 'مراجعة v$version';
  }

  @override
  String get leaveBlank => 'اترك المنتج فارغًا لتسعيره لاحقًا بشكل منفصل.';

  @override
  String get unitPrice => 'سعر الوحدة';

  @override
  String get discount => 'الخصم';

  @override
  String get total => 'الإجمالي';

  @override
  String createVersion(int version) {
    return 'إنشاء v$version';
  }

  @override
  String get quotationSaved => 'تم حفظ عرض السعر';

  @override
  String get priceAtLeastOne => 'ضع سعرًا لمنتج واحد على الأقل.';

  @override
  String approveTitle(Object version) {
    return 'هل وافق العميل على $version؟';
  }

  @override
  String approveBody(Object amount) {
    return 'سيصبح $amount السعر المتفق عليه. تغييره لاحقًا يعني نسخة جديدة.';
  }

  @override
  String rejectTitle(Object version) {
    return 'هل رفض العميل $version؟';
  }

  @override
  String get rejectBody => 'يمكنك مراجعته في نسخة جديدة بعد ذلك.';

  @override
  String get paymentsTitle => 'المدفوعات';

  @override
  String get recordPayment => 'تسجيل دفعة';

  @override
  String get nothingReceived => 'لم يُستلم شيء بعد.';

  @override
  String get recordPaymentTitle => 'تسجيل دفعة';

  @override
  String get amount => 'المبلغ';

  @override
  String get how => 'طريقة الدفع';

  @override
  String get whatItIs => 'نوع الدفعة';

  @override
  String get reference => 'المرجع';

  @override
  String get referenceHint => 'رقم الإيصال أو التحويل';

  @override
  String get record => 'تسجيل';

  @override
  String get enterAmount => 'أدخل المبلغ.';

  @override
  String get paymentRecorded => 'تم تسجيل الدفعة';

  @override
  String confirmPaymentTitle(Object amount) {
    return 'تسجيل $amount؟';
  }

  @override
  String confirmPaymentBody(Object kind, Object method) {
    return '$method · $kind. لا يمكن تعديل المدفوعات أو حذفها بعد ذلك.';
  }

  @override
  String get historyTitle => 'السجل';

  @override
  String get nothingRecorded => 'لم يُسجَّل شيء بعد.';

  @override
  String get reportsTitle => 'التقارير';

  @override
  String get reportsSubtitle => 'صدّر الطلبات ومنتجاتها إلى Excel.';

  @override
  String get whatToInclude => 'ما الذي يُضمَّن';

  @override
  String get dateRange => 'الفترة';

  @override
  String get everything => 'كل شيء';

  @override
  String get whatYouGet => 'ما ستحصل عليه';

  @override
  String get reportItemsSheet => 'المنتجات — صف لكل منتج.';

  @override
  String get reportRequestsSheet =>
      'الطلبات — صف لكل طلب، مع الإجمالي والمدفوع والمتبقي.';

  @override
  String get createWorkbook => 'إنشاء الملف';

  @override
  String get workbookSaved => 'تم حفظ الملف';

  @override
  String get showInFolder => 'إظهار في المجلد';

  @override
  String get nothingMatchesFilters => 'لا شيء يطابق عوامل التصفية.';

  @override
  String get workbookFailed => 'تعذّرت كتابة الملف.';

  @override
  String exportSummary(int items, int requests) {
    return '$items صف منتجات · $requests طلب';
  }

  @override
  String get tabOverview => 'نظرة عامة';

  @override
  String get tabAttention => 'المتابعة';

  @override
  String get tabMoney => 'المال';

  @override
  String get tabPeople => 'الفريق';

  @override
  String greetingMorning(Object name) {
    return 'صباح الخير، $name';
  }

  @override
  String greetingAfternoon(Object name) {
    return 'مساء الخير، $name';
  }

  @override
  String greetingEvening(Object name) {
    return 'مساء الخير، $name';
  }

  @override
  String get openJobs => 'أعمال مفتوحة';

  @override
  String get cameInThisWeek => 'ورد هذا الأسبوع';

  @override
  String get finishedThisWeek => 'أُنجز هذا الأسبوع';

  @override
  String get blocked => 'متوقف';

  @override
  String get pastDue => 'متأخر';

  @override
  String get whereWorkSits => 'أين يقف العمل';

  @override
  String get latest => 'الأحدث';

  @override
  String get nothingOpen => 'لا شيء مفتوح.';

  @override
  String get attentionTitle => 'يحتاج إلى متابعة';

  @override
  String attentionSubtitle(int count, int total) {
    return '$count من $total أعمال مفتوحة';
  }

  @override
  String get nothingStuck => 'لا شيء متوقف';

  @override
  String get nothingStuckBody => 'كل الأعمال المفتوحة تسير.';

  @override
  String get pastPromisedDate => 'تجاوز الموعد المحدد';

  @override
  String get nobodyPickedUp => 'لم يتسلمها أحد';

  @override
  String get acrossEveryRequest => 'على مستوى كل الطلبات';

  @override
  String stillOwing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طلب عليه مستحقات',
      many: '$count طلبًا عليه مستحقات',
      few: '$count طلبات عليها مستحقات',
      two: 'طلبان عليهما مستحقات',
      one: 'طلب واحد عليه مستحقات',
      zero: 'لا مستحقات',
    );
    return '$_temp0';
  }

  @override
  String get approvedInTotal => 'إجمالي المعتمد';

  @override
  String get received => 'المستلم';

  @override
  String get moneyNote =>
      'تُحتسب المستحقات فقط للأعمال التي لها عرض سعر معتمد. الدفعة المقدمة قبل التسعير تظهر ضمن المستلم فقط.';

  @override
  String get waitingOnPayment => 'بانتظار الدفع';

  @override
  String get noneOnPayment => 'لا يوجد عمل متوقف بانتظار الدفع.';

  @override
  String get peopleTitle => 'الفريق';

  @override
  String get peopleSubtitle => 'الأعمال المفتوحة، الأكثر انشغالًا أولًا';

  @override
  String get noOpenWork => 'لا أعمال مفتوحة مسندة لأحد.';

  @override
  String openCount(int count) {
    return '$count مفتوح';
  }

  @override
  String inProgressCount(int count) {
    return '$count قيد التنفيذ';
  }

  @override
  String lateCount(int count) {
    return '$count متأخر';
  }

  @override
  String get whatTheyAskedFor => 'ما طلبه العميل';

  @override
  String get whoIsOnIt => 'من يعمل عليه';

  @override
  String get whatHappened => 'ما الذي حدث';

  @override
  String get stillOwed => 'المتبقي';

  @override
  String get opened => 'فُتح';

  @override
  String get nobodyAssigned => 'لم يُسند لأحد';

  @override
  String paidInAdvanceAmount(Object amount) {
    return 'دُفع $amount مقدمًا. لم يُعتمد شيء بعد، لذلك لا يوجد رصيد.';
  }

  @override
  String get navHelp => 'المساعدة';

  @override
  String get helpCenter => 'مركز المساعدة';

  @override
  String get helpSubtitle => 'كيف تنجز عملك في نظام Inmore للعمليات.';

  @override
  String get helpSearchHint => 'ابحث في المساعدة';

  @override
  String get helpNoResults => 'لا يوجد في المساعدة ما يطابق ذلك';

  @override
  String get helpNoResultsBody => 'جرّب كلمة أخرى، أو اختر موضوعًا من القائمة.';

  @override
  String get helpAllTopics => 'كل المواضيع';

  @override
  String get takeTheTour => 'الجولة التعريفية';

  @override
  String get tourNext => 'التالي';

  @override
  String get tourBack => 'السابق';

  @override
  String get tourSkip => 'تخطي الجولة';

  @override
  String get tourDone => 'فهمت';

  @override
  String tourStepOf(int current, int total) {
    return '$current من $total';
  }

  @override
  String tourWelcomeTitle(String name) {
    return 'أهلًا بك في Inmore يا $name';
  }

  @override
  String get tourWelcomeManager =>
      'جولة سريعة لدقيقة واحدة. كل طلب يعمل عليه المحل موجود هنا، من أول اتصال حتى آخر دفعة.';

  @override
  String get tourWelcomeWorker =>
      'جولة سريعة لدقيقة واحدة. العمل المسند إليك موجود هنا، ومعه الطلب الذي ينتمي إليه كل عمل.';

  @override
  String get tourBoardTitle => 'لوحة العمل';

  @override
  String get tourBoardBody =>
      'كل الطلبات المفتوحة. أي طلب متوقف أو متأخر أو بلا مشرف يظهر في الأعلى تحت «يحتاج إلى متابعة».';

  @override
  String get tourHomeWorkTitle => 'مهامك';

  @override
  String get tourHomeWorkBody =>
      'كل ما أُسند إليك، مقسّمًا إلى جارٍ ولم يبدأ ومتوقف. غيّر حالة المهمة من بطاقتها مباشرة.';

  @override
  String get tourNewRequestTitle => 'ابدأ طلبًا جديدًا';

  @override
  String get tourNewRequestBody =>
      'عندما يطلب العميل شيئًا، سجّله من هنا. كل ما طلبه يدخل في طلب واحد. الاختصار: Ctrl+N.';

  @override
  String get tourMyWorkTitle => 'مهامك الشخصية';

  @override
  String get tourMyWorkBody =>
      'العمل المسند إليك شخصيًا. الرقم هو عدد ما لم يُنجز بعد.';

  @override
  String get tourSearchTitle => 'اعثر على أي طلب';

  @override
  String get tourSearchBody =>
      'اكتب رقم الطلب أو اسم العميل أو جزءًا من العنوان. يعمل من أي شاشة بالضغط على Ctrl+K.';

  @override
  String get tourCustomersTitle => 'العملاء';

  @override
  String get tourCustomersBody =>
      'ابحث عن أي عميل بالاسم أو الشركة أو رقم الهاتف، بأي طريقة كتابة.';

  @override
  String get tourReportsTitle => 'التقارير';

  @override
  String get tourReportsBody =>
      'صدّر الطلبات والمنتجات والمدفوعات إلى ملف Excel.';

  @override
  String get tourHelpTitle => 'المساعدة دائمًا هنا';

  @override
  String get tourHelpBody =>
      'شروحات خطوة بخطوة لكل ما في التطبيق، وهذه الجولة متى أردتها. الاختصار: F1.';

  @override
  String get tourAccountTitle => 'حسابك';

  @override
  String get tourAccountBody =>
      'غيّر اللغة أو المظهر، واطّلع على اختصارات لوحة المفاتيح، أو سجّل الخروج.';

  @override
  String get editProduct => 'تعديل المنتج';

  @override
  String get productAdded => 'أُضيف المنتج';

  @override
  String get productSaved => 'حُفظ المنتج';

  @override
  String get itemCancelledPriced =>
      'كان مسعّرًا بالفعل، لذلك بقي مع علامة «ملغى»';

  @override
  String get markCompleted => 'تحديد كمكتمل';

  @override
  String completeTitle(Object reference) {
    return 'هل اكتمل $reference؟';
  }

  @override
  String get completeBody =>
      'سيختفي من لوحة العمل، ويمكنك إعادة فتحه لاحقًا عند الحاجة.';

  @override
  String completeOpenTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ستُغلق $count مهمة لم تُنجز.',
      few: 'ستُغلق $count مهام لم تُنجز.',
      two: 'ستُغلق مهمتان لم تُنجزا.',
      one: 'ستُغلق مهمة واحدة لم تُنجز.',
    );
    return '$_temp0';
  }

  @override
  String completeStillOwed(Object amount) {
    return 'ما زال مستحقًا عليه $amount.';
  }

  @override
  String get requestCompletedToast => 'اكتمل الطلب';

  @override
  String completedOn(Object date) {
    return 'اكتمل في $date';
  }

  @override
  String cancelledBecause(Object reason) {
    return 'أُلغي — $reason';
  }

  @override
  String get reopen => 'إعادة فتح';

  @override
  String reopenTitle(Object reference) {
    return 'إعادة فتح $reference؟';
  }

  @override
  String get reopenBody =>
      'اختر المرحلة التي يعود إليها. سيعود إلى لوحة العمل.';

  @override
  String get requestReopened => 'أُعيد فتح الطلب';

  @override
  String get editDetails => 'تعديل التفاصيل';

  @override
  String get detailsSaved => 'حُفظت التفاصيل';

  @override
  String get moreActions => 'المزيد';

  @override
  String get reassign => 'إعادة إسناد';

  @override
  String reassignTitle(Object task) {
    return 'إعادة إسناد «$task»';
  }

  @override
  String get cancelTask => 'إلغاء هذا العمل';

  @override
  String cancelTaskTitle(Object task) {
    return 'إلغاء «$task»؟';
  }

  @override
  String get cancelTaskBody => 'سيبقى في السجل على أنه ملغى.';

  @override
  String get taskUpdated => 'حُدّث العمل';

  @override
  String get recordCost => 'تسجيل التكلفة';

  @override
  String costTitle(Object partner) {
    return 'كم كانت تكلفة $partner؟';
  }

  @override
  String get costRecorded => 'سُجّلت التكلفة';

  @override
  String get newPartner => 'شريك جديد';

  @override
  String get fieldContact => 'الشخص المسؤول';

  @override
  String get fieldServices => 'ما يقدمونه';

  @override
  String get partnerAdded => 'أُضيف الشريك';

  @override
  String get editDraft => 'تعديل';

  @override
  String editDraftTitle(Object version) {
    return 'تعديل v$version';
  }

  @override
  String get quotationUpdated => 'حُدّث عرض السعر';
}
