import 'package:flutter/material.dart';
import 'package:inmore_core/inmore_core.dart';

/// The help center's articles, in both languages.
///
/// Kept here rather than in the ARB files: these are long, structured pieces
/// of writing, and having the English and Arabic of each paragraph side by
/// side is what keeps them saying the same thing when one is edited. The short
/// labels around them (search, buttons, the tour) are in the ARB files like
/// every other string.
///
/// Every article describes what the app actually does today — check the
/// screen before changing one. Names of buttons and screens are quoted exactly
/// as the app shows them in that language.

/// One piece of text in English and Arabic.
@immutable
class Bi {
  const Bi(this.en, this.ar);

  final String en;
  final String ar;

  String of(BuildContext context) => pick(Localizations.localeOf(context));

  String pick(Locale locale) => locale.languageCode == 'ar' ? ar : en;
}

/// Who an article is written for. The help only shows what the reader's role
/// can actually do, so a designer is never told about a button they don't
/// have.
enum HelpAudience {
  everyone,

  /// Owner and supervisors: they create and run requests.
  managers,

  /// Owner and supervisors: they see prices, payments and reports.
  money,

  /// Designers and production: they work on tasks.
  doers;

  bool allows(Employee e) => switch (this) {
        everyone => true,
        managers => e.role.canManageRequests,
        money => e.role.canSeeMoney,
        doers => !e.role.canManageRequests,
      };
}

sealed class HelpBlock {
  const HelpBlock();

  Iterable<Bi> get texts;
}

class HelpText extends HelpBlock {
  const HelpText(this.text);
  final Bi text;
  @override
  Iterable<Bi> get texts => [text];
}

/// A bulleted list.
class HelpList extends HelpBlock {
  const HelpList(this.items);
  final List<Bi> items;
  @override
  Iterable<Bi> get texts => items;
}

/// Numbered steps.
class HelpSteps extends HelpBlock {
  const HelpSteps(this.steps);
  final List<Bi> steps;
  @override
  Iterable<Bi> get texts => steps;
}

/// A highlighted note.
class HelpTip extends HelpBlock {
  const HelpTip(this.text);
  final Bi text;
  @override
  Iterable<Bi> get texts => [text];
}

/// Keys and what they do.
class HelpKeys extends HelpBlock {
  const HelpKeys(this.keys);
  final List<(String, Bi)> keys;
  @override
  Iterable<Bi> get texts => keys.map((k) => k.$2);
}

@immutable
class HelpArticle {
  const HelpArticle({
    required this.id,
    required this.title,
    required this.blocks,
    this.audience = HelpAudience.everyone,
  });

  final String id;
  final Bi title;
  final List<HelpBlock> blocks;
  final HelpAudience audience;

  /// Whether every word of [query] appears in the title or body, in the
  /// reader's language.
  bool matches(String query, Locale locale) {
    final words = query.toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    if (words.isEmpty) return true;
    final haystack = [
      title.pick(locale),
      for (final b in blocks)
        for (final t in b.texts) t.pick(locale),
    ].join(' ').toLowerCase();
    return words.every(haystack.contains);
  }
}

@immutable
class HelpSection {
  const HelpSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.articles,
  });

  final String id;
  final Bi title;
  final IconData icon;
  final List<HelpArticle> articles;
}

/// The sections and articles a given person should see, in order.
List<HelpSection> helpFor(Employee e) => [
      for (final s in helpSections)
        if (s.articles.any((a) => a.audience.allows(e)))
          HelpSection(
            id: s.id,
            title: s.title,
            icon: s.icon,
            articles: [
              for (final a in s.articles)
                if (a.audience.allows(e)) a,
            ],
          ),
    ];

const helpSections = <HelpSection>[
  // ---------------------------------------------------------------- start
  HelpSection(
    id: 'start',
    title: Bi('Getting started', 'البداية'),
    icon: Icons.flag_outlined,
    articles: [
      HelpArticle(
        id: 'around',
        title: Bi('Finding your way around', 'التنقل في التطبيق'),
        blocks: [
          HelpText(Bi(
            'The sidebar takes you to every part of the app. What it shows depends on your role:',
            'الشريط الجانبي يأخذك إلى كل أجزاء التطبيق، وما يظهر فيه يعتمد على دورك:',
          )),
          HelpList([
            Bi('Work board — every open request. The owner and supervisors start here.',
                'لوحة العمل — كل الطلبات المفتوحة. يبدأ منها المالك والمشرفون.'),
            Bi('My work — the tasks given to you. Designers and production start here.',
                'مهامي — المهام المسندة إليك. يبدأ منها المصممون وفريق الإنتاج.'),
            Bi('Customers — everyone the shop has worked with.',
                'العملاء — كل من تعامل معهم المحل.'),
            Bi('Reports — Excel exports, for the owner and supervisors.',
                'التقارير — ملفات Excel، للمالك والمشرفين.'),
            Bi('Help — this page.', 'المساعدة — هذه الصفحة.'),
          ]),
          HelpText(Bi(
            'Search is at the top of the sidebar. Your name at the bottom opens your account menu. Collapse sidebar folds the sidebar down to icons when you need more room.',
            'البحث في أعلى الشريط الجانبي، واسمك في أسفله يفتح قائمة حسابك. «طي الشريط الجانبي» يصغّره إلى أيقونات عندما تحتاج مساحة أكبر.',
          )),
        ],
      ),
      HelpArticle(
        id: 'search',
        title: Bi('Finding a request', 'البحث عن طلب'),
        blocks: [
          HelpSteps([
            Bi('Click Search at the top of the sidebar, or press Ctrl+K on any screen.',
                'اضغط «بحث» في أعلى الشريط الجانبي، أو اضغط Ctrl+K من أي شاشة.'),
            Bi('Type a request number such as 1042, part of the customer’s name, or a word from the title.',
                'اكتب رقم الطلب مثل 1042، أو جزءًا من اسم العميل، أو كلمة من عنوان الطلب.'),
            Bi('Pick the request from the list to open it.',
                'اختر الطلب من القائمة لفتحه.'),
          ]),
          HelpTip(Bi(
            'Search finds closed and cancelled requests too, so it’s the quickest way to answer “what happened to that order?”',
            'البحث يجد الطلبات المغلقة والملغاة أيضًا، لذلك هو أسرع طريقة للإجابة عن «ماذا حدث لذلك الطلب؟»',
          )),
        ],
      ),
      HelpArticle(
        id: 'settings',
        title: Bi('Language and appearance', 'اللغة والمظهر'),
        blocks: [
          HelpSteps([
            Bi('Click your name at the bottom of the sidebar.',
                'اضغط على اسمك في أسفل الشريط الجانبي.'),
            Bi('Choose Settings.', 'اختر «الإعدادات».'),
            Bi('Pick English or العربية, and a light, dark or system appearance.',
                'اختر English أو العربية، ومظهرًا فاتحًا أو داكنًا أو حسب النظام.'),
          ]),
          HelpText(Bi(
            'Your choice is saved on this computer and stays the same next time. You can also switch the language on the sign-in screen.',
            'يُحفظ اختيارك على هذا الجهاز ويبقى كما هو في المرة القادمة. يمكنك أيضًا تغيير اللغة من شاشة تسجيل الدخول.',
          )),
        ],
      ),
      HelpArticle(
        id: 'shortcuts',
        title: Bi('Keyboard shortcuts', 'اختصارات لوحة المفاتيح'),
        blocks: [
          HelpKeys([
            ('Ctrl K', Bi('Find a request', 'البحث عن طلب')),
            (
              'Ctrl N',
              Bi('New request (owner and supervisors)',
                  'طلب جديد (للمالك والمشرفين)')
            ),
            ('F5', Bi('Refresh the screen', 'تحديث الشاشة')),
            ('F1', Bi('Open this help', 'فتح المساعدة')),
          ]),
        ],
      ),
      HelpArticle(
        id: 'live',
        title: Bi('Live updates and losing the connection',
            'التحديث المباشر وانقطاع الاتصال'),
        blocks: [
          HelpText(Bi(
            'Screens update by themselves when a colleague changes something — you don’t need to refresh.',
            'تتحدث الشاشات تلقائيًا عندما يغيّر أحد الزملاء شيئًا — لا حاجة إلى التحديث يدويًا.',
          )),
          HelpText(Bi(
            'If the connection drops, a bar appears at the top and you keep seeing what was last loaded. Nothing can be saved until the connection is back; when it is, everything refreshes on its own.',
            'إذا انقطع الاتصال يظهر شريط في الأعلى وتبقى ترى آخر ما تم تحميله. لا يمكن حفظ أي شيء حتى يعود الاتصال، وعندها يتحدث كل شيء تلقائيًا.',
          )),
        ],
      ),
      HelpArticle(
        id: 'errors',
        title: Bi('When something goes wrong', 'عند حدوث خطأ'),
        blocks: [
          HelpText(Bi(
            'If something can’t be saved, the app says why — for example that you’re offline, or that your account isn’t allowed to do it.',
            'إذا تعذّر حفظ شيء، يوضح التطبيق السبب — مثلًا أنك غير متصل، أو أن حسابك لا يملك صلاحية ذلك.',
          )),
          HelpTip(Bi(
            'If the same message keeps coming back, click Copy details and send it to whoever looks after the system.',
            'إذا تكررت الرسالة نفسها، اضغط «نسخ التفاصيل» وأرسلها إلى المسؤول عن النظام.',
          )),
        ],
      ),
    ],
  ),

  // ------------------------------------------------------------- requests
  HelpSection(
    id: 'requests',
    title: Bi('Requests', 'الطلبات'),
    icon: Icons.receipt_long_outlined,
    articles: [
      HelpArticle(
        id: 'how',
        title: Bi('How a request works', 'كيف يعمل الطلب'),
        blocks: [
          HelpText(Bi(
            'A request is one customer asking for something. It holds every product they asked for, the work being done, and the full history — all on one page.',
            'الطلب هو عميل واحد يطلب شيئًا. يضم كل المنتجات التي طلبها، والأعمال الجارية عليه، وسجله الكامل — كله في صفحة واحدة.',
          )),
          HelpText(Bi('Each request moves through these stages:',
              'يمر كل طلب بهذه المراحل:')),
          HelpList([
            Bi('New', 'جديد'),
            Bi('Quotation', 'عرض السعر'),
            Bi('Design', 'التصميم'),
            Bi('Customer approval', 'موافقة العميل'),
            Bi('Production', 'الإنتاج'),
            Bi('Delivery', 'التسليم'),
          ]),
          HelpText(Bi(
            'Separately from its stage, a request can be waiting — on the customer, on payment, on a partner, or simply on hold. Waiting doesn’t change the stage: a job in production that is waiting for payment still shows as in production.',
            'بشكل منفصل عن المرحلة، قد يكون الطلب متوقفًا — بانتظار العميل أو الدفع أو الشريك، أو معلّقًا. التوقف لا يغيّر المرحلة: طلب في الإنتاج ينتظر الدفع يبقى ظاهرًا في الإنتاج.',
          )),
        ],
      ),
      HelpArticle(
        id: 'board',
        audience: HelpAudience.managers,
        title: Bi('Using the work board', 'استخدام لوحة العمل'),
        blocks: [
          HelpText(Bi(
            'Requests that need you — waiting on something, past their due date, or without a supervisor — are grouped at the top under Needs attention. Click any row to open the request.',
            'الطلبات التي تحتاجك — المتوقفة، أو المتأخرة عن موعدها، أو التي بلا مشرف — تظهر في الأعلى تحت «يحتاج إلى متابعة». اضغط على أي صف لفتح الطلب.',
          )),
          HelpList([
            Bi('The tabs along the top show one stage at a time, with how many requests are in each.',
                'التبويبات في الأعلى تعرض مرحلة واحدة في كل مرة، مع عدد الطلبات في كل منها.'),
            Bi('The search box narrows the board by customer, title or request number.',
                'مربع البحث يضيّق اللوحة حسب العميل أو العنوان أو رقم الطلب.'),
            Bi('Mine shows only the requests you supervise.',
                '«طلباتي» تعرض فقط الطلبات التي تشرف عليها.'),
            Bi('Include closed adds completed and cancelled requests.',
                '«إظهار المغلقة» تضيف الطلبات المكتملة والملغاة.'),
            Bi('Sort changes the order: newest first, by due date, or by request number.',
                '«ترتيب» يغيّر الترتيب: الأحدث أولًا، أو حسب تاريخ الاستحقاق، أو حسب رقم الطلب.'),
          ]),
        ],
      ),
      HelpArticle(
        id: 'new',
        audience: HelpAudience.managers,
        title: Bi('Creating a request', 'إنشاء طلب'),
        blocks: [
          HelpSteps([
            Bi('Click New request on the work board, or press Ctrl+N.',
                'اضغط «طلب جديد» في لوحة العمل، أو اضغط Ctrl+N.'),
            Bi('Find the customer by name, company or phone. If they’re not there yet, choose New customer and add them.',
                'ابحث عن العميل بالاسم أو الشركة أو الهاتف. إن لم يكن موجودًا، اختر «عميل جديد» وأضفه.'),
            Bi('Give the request a short title, such as “Cafe opening pack”, and the date it’s needed by if there is one. Notes are for what the customer actually said.',
                'أعطِ الطلب عنوانًا قصيرًا مثل «تجهيزات افتتاح مقهى»، وتاريخ الحاجة إليه إن وُجد. الملاحظات لما قاله العميل فعلًا.'),
            Bi('Add each product: pick it from the catalog, or choose Something else and type it. Then the quantity, the unit, and any spec — size, colours, material, finishing.',
                'أضف كل منتج: اختره من الكتالوج، أو اختر «شيء آخر» واكتبه. ثم الكمية والوحدة وأي مواصفات — المقاس والألوان والخامة والتشطيب.'),
            Bi('Click Create request.', 'اضغط «إنشاء الطلب».'),
          ]),
          HelpTip(Bi(
            'Forgot something, or the customer called back with more? Open the request and click Add product in the Products panel.',
            'نسيت شيئًا، أو اتصل العميل ليضيف المزيد؟ افتح الطلب واضغط «إضافة منتج» في لوحة «المنتجات».',
          )),
        ],
      ),
      HelpArticle(
        id: 'stages',
        audience: HelpAudience.managers,
        title: Bi('Moving a request along', 'تحريك الطلب بين المراحل'),
        blocks: [
          HelpSteps([
            Bi('Open the request.', 'افتح الطلب.'),
            Bi('Click a stage on the progress bar at the top to move the request there — forward or back.',
                'اضغط على مرحلة في شريط التقدم بالأعلى لنقل الطلب إليها — للأمام أو للخلف.'),
            Bi('When the job is waiting, use the buttons next to Blocked on: Waiting on customer, Waiting on payment, Waiting on partner or On hold.',
                'عندما يتوقف العمل، استخدم الأزرار بجانب «متوقف بسبب»: بانتظار العميل، بانتظار الدفع، بانتظار الشريك، أو معلّق.'),
            Bi('Click Moving when it’s going again.',
                'اضغط «يسير» عندما يستأنف العمل.'),
          ]),
          HelpTip(Bi(
            'Every move is written into the request’s History with your name and the time.',
            'كل تغيير يُسجَّل في «السجل» الخاص بالطلب مع اسمك والوقت.',
          )),
        ],
      ),
      HelpArticle(
        id: 'details',
        audience: HelpAudience.managers,
        title: Bi('Supervisor, due date and notes',
            'المشرف وتاريخ الاستحقاق والملاحظات'),
        blocks: [
          HelpText(Bi(
            'The supervisor is the person responsible for the request. In the Details panel, click the supervisor’s name and choose someone from the list — or Nobody yet. A request with no supervisor is flagged on the work board until someone takes it.',
            'المشرف هو المسؤول عن الطلب. في لوحة «التفاصيل»، اضغط على اسم المشرف واختر شخصًا من القائمة — أو «لا أحد بعد». الطلب الذي بلا مشرف يظهر بعلامة في لوحة العمل حتى يتولاه أحد.',
          )),
          HelpText(Bi(
            'To change the title, the date it’s needed by, or the notes, click the ⋮ menu at the top right and choose Edit details.',
            'لتغيير العنوان أو تاريخ الحاجة إليه أو الملاحظات، اضغط قائمة ⋮ في أعلى الصفحة واختر «تعديل التفاصيل».',
          )),
        ],
      ),
      HelpArticle(
        id: 'products',
        audience: HelpAudience.managers,
        title: Bi('Adding, changing or removing products',
            'إضافة المنتجات أو تعديلها أو حذفها'),
        blocks: [
          HelpList([
            Bi('Add: click Add product in the Products panel.',
                'الإضافة: اضغط «إضافة منتج» في لوحة «المنتجات».'),
            Bi('Change the quantity, unit or spec: click the pencil icon next to the product. This is only possible while it is still Pending — once a price is approved for it, revise the quotation instead.',
                'تعديل الكمية أو الوحدة أو المواصفات: اضغط أيقونة القلم بجانب المنتج. هذا ممكن فقط ما دام «قيد الانتظار» — بعد اعتماد سعره، راجع عرض السعر بدلًا من ذلك.'),
            Bi('Remove: click the bin icon and confirm.',
                'الحذف: اضغط أيقونة الحذف ثم أكّد.'),
          ]),
          HelpTip(Bi(
            'A product that has already been priced isn’t deleted — it’s kept and marked Cancelled, so the quotation still shows what it priced. Either way, the change is in the History.',
            'المنتج الذي سبق تسعيره لا يُحذف — بل يبقى مع علامة «ملغى»، ليظل عرض السعر يُظهر ما سعّره. وفي الحالتين يُسجَّل التغيير في «السجل».',
          )),
        ],
      ),
      HelpArticle(
        id: 'complete',
        audience: HelpAudience.managers,
        title: Bi('Completing a request', 'إكمال الطلب'),
        blocks: [
          HelpSteps([
            Bi('Open the request.', 'افتح الطلب.'),
            Bi('Click Mark completed, next to the Blocked on buttons.',
                'اضغط «تحديد كمكتمل» بجانب أزرار «متوقف بسبب».'),
            Bi('Check what the confirmation says, then confirm.',
                'راجع ما تقوله رسالة التأكيد، ثم أكّد.'),
          ]),
          HelpText(Bi(
            'The confirmation warns you if any work on the request is unfinished — it will be closed as cancelled — and, if you can see prices, if money is still owed.',
            'تنبّهك رسالة التأكيد إذا كان هناك عمل لم يُنجز في الطلب — سيُغلق كملغى — وإذا كنت ترى الأسعار، إن كان هناك مبلغ ما زال مستحقًا.',
          )),
          HelpTip(Bi(
            'A completed request leaves the work board. Find it with Search or Include closed.',
            'يختفي الطلب المكتمل من لوحة العمل. يمكنك إيجاده بالبحث أو بتفعيل «إظهار المغلقة».',
          )),
        ],
      ),
      HelpArticle(
        id: 'reopen',
        audience: HelpAudience.managers,
        title: Bi('Reopening a request', 'إعادة فتح طلب'),
        blocks: [
          HelpText(Bi(
            'If a completed request turns out not to be finished, or a cancelled one comes back, open it and click Reopen. Choose the stage it goes back to and confirm. It returns to the work board, and the History shows it was reopened.',
            'إذا تبيّن أن طلبًا مكتملًا لم ينتهِ بعد، أو عاد طلب ملغى، افتحه واضغط «إعادة فتح». اختر المرحلة التي يعود إليها ثم أكّد. سيعود إلى لوحة العمل، ويُظهر «السجل» أنه أُعيد فتحه.',
          )),
          HelpText(Bi(
            'Work that was closed when the request was closed stays closed — assign it again if it still needs doing.',
            'الأعمال التي أُغلقت عند إغلاق الطلب تبقى مغلقة — أسندها من جديد إن كانت ما تزال مطلوبة.',
          )),
        ],
      ),
      HelpArticle(
        id: 'cancel',
        audience: HelpAudience.managers,
        title: Bi('Cancelling a request', 'إلغاء طلب'),
        blocks: [
          HelpSteps([
            Bi('Open the request.', 'افتح الطلب.'),
            Bi('Click the ⋮ menu at the top right and choose Cancel request.',
                'اضغط قائمة ⋮ في أعلى الصفحة واختر «إلغاء الطلب».'),
            Bi('Write why — for example “Customer went elsewhere” — and confirm.',
                'اكتب السبب — مثلًا «العميل ذهب إلى جهة أخرى» — ثم أكّد.'),
          ]),
          HelpText(Bi(
            'Any unfinished work on it is closed as cancelled. A cancelled request leaves the work board, but you can still find it with Search, or by turning on Include closed — and reopen it if it comes back.',
            'أي عمل لم يُنجز فيه يُغلق كملغى. يختفي الطلب الملغى من لوحة العمل، لكن يمكنك إيجاده بالبحث أو بتفعيل «إظهار المغلقة» — وإعادة فتحه إن عاد.',
          )),
        ],
      ),
      HelpArticle(
        id: 'history',
        title: Bi('The History panel', 'لوحة السجل'),
        blocks: [
          HelpText(Bi(
            'Everything that happens to a request is written into its History automatically — what changed, who did it and when. Nobody can edit or delete it.',
            'كل ما يحدث للطلب يُكتب في «السجل» تلقائيًا — ما الذي تغيّر ومن قام به ومتى. لا أحد يستطيع تعديله أو حذفه.',
          )),
          HelpText(Bi(
            'If something was done by mistake, putting it right shows up as a new entry, so the story is always complete.',
            'إذا حدث شيء عن طريق الخطأ، يظهر تصحيحه كإدخال جديد، فتبقى القصة كاملة دائمًا.',
          )),
        ],
      ),
    ],
  ),

  // ----------------------------------------------------------------- work
  HelpSection(
    id: 'work',
    title: Bi('Work and tasks', 'الأعمال والمهام'),
    icon: Icons.task_alt_rounded,
    articles: [
      HelpArticle(
        id: 'mywork',
        title: Bi('Your tasks', 'مهامك'),
        blocks: [
          HelpText(Bi(
            'My work lists everything given to you, grouped into In progress, To do and Blocked. A task past its due date is marked Overdue.',
            '«مهامي» تعرض كل ما أُسند إليك، مقسّمًا إلى «قيد التنفيذ» و«لم يبدأ» و«متوقف». المهمة التي تجاوزت موعدها تظهر عليها علامة «متأخر».',
          )),
          HelpSteps([
            Bi('Use the buttons on the task’s card — To do, Doing, Blocked, Done — to show where it stands.',
                'استخدم الأزرار على بطاقة المهمة — لم يبدأ، جارٍ، متوقف، منجز — لتوضيح حالتها.'),
            Bi('Click the card, or the arrow icon, to open the request it belongs to.',
                'اضغط على البطاقة، أو على أيقونة السهم، لفتح الطلب الذي تنتمي إليه.'),
          ]),
          HelpTip(Bi(
            'When you mark a task Done it leaves your list, and the request shows how long it took.',
            'عندما تضع علامة «منجز» على المهمة تختفي من قائمتك، ويظهر في الطلب الوقت الذي استغرقته.',
          )),
        ],
      ),
      HelpArticle(
        id: 'assign',
        audience: HelpAudience.managers,
        title: Bi('Assigning work', 'إسناد العمل'),
        blocks: [
          HelpSteps([
            Bi('Open the request and click Assign work in the Work panel.',
                'افتح الطلب واضغط «إسناد عمل» في لوحة «الأعمال».'),
            Bi('Describe what needs doing, such as “Cup artwork”, and choose the kind of work.',
                'صِف ما يجب عمله، مثل «تصميم الأكواب»، واختر نوع العمل.'),
            Bi('Choose which product it’s for, or The whole request.',
                'اختر المنتج الذي يخصه، أو «الطلب بالكامل».'),
            Bi('Pick a due date if there is one — work past its date is flagged as overdue.',
                'اختر تاريخ استحقاق إن وُجد — العمل الذي يتجاوز موعده يظهر عليه «متأخر».'),
            Bi('Choose who will do it. If the work goes outside the shop, tick Going to an external partner and choose the partner instead.',
                'اختر من سيقوم به. إذا كان العمل سيُنفَّذ خارج المحل، فعّل «يُرسل إلى شريك خارجي» واختر الشريك بدلًا من ذلك.'),
            Bi('Click Add. It appears in that person’s My work straight away.',
                'اضغط «إضافة». يظهر العمل فورًا في «مهامي» لدى ذلك الشخص.'),
          ]),
        ],
      ),
      HelpArticle(
        id: 'managework',
        audience: HelpAudience.managers,
        title: Bi('Moving work along, reassigning or cancelling it',
            'تحريك العمل أو إعادة إسناده أو إلغاؤه'),
        blocks: [
          HelpText(Bi(
            'In the Work panel, click the ⋮ next to a piece of work:',
            'في لوحة «الأعمال»، اضغط ⋮ بجانب العمل:',
          )),
          HelpList([
            Bi('To do, In progress, Blocked or Done — sets where it stands. This is how a partner’s job gets marked done.',
                'لم يبدأ، قيد التنفيذ، متوقف، أو منجز — لتحديد حالته. بهذه الطريقة تُعلَّم مهمة الشريك كمنجزة.'),
            Bi('Reassign — gives it to someone else, or to a partner.',
                'إعادة إسناد — لإعطائه لشخص آخر أو لشريك.'),
            Bi('Record cost — what a partner charged for it (owner and supervisors only).',
                'تسجيل التكلفة — ما تقاضاه الشريك مقابله (للمالك والمشرفين فقط).'),
            Bi('Cancel this work — when it’s no longer needed. It stays in the History.',
                'إلغاء هذا العمل — عندما لا يعود مطلوبًا. يبقى في «السجل».'),
          ]),
        ],
      ),
      HelpArticle(
        id: 'partners',
        audience: HelpAudience.managers,
        title: Bi('Working with partners', 'العمل مع الشركاء'),
        blocks: [
          HelpText(Bi(
            'A partner is an outside printer or supplier who does part of a job. When assigning work, tick Going to an external partner and choose them. If they aren’t in the list yet, click the add button next to it and enter their name, contact person, phone and what they do.',
            'الشريك مطبعة أو مورد خارجي ينفّذ جزءًا من العمل. عند إسناد العمل، فعّل «يُرسل إلى شريك خارجي» واختره. إن لم يكن في القائمة بعد، اضغط زر الإضافة بجانبها وأدخل الاسم والشخص المسؤول والهاتف وما يقدمونه.',
          )),
          HelpTip(Bi(
            'A partner can’t update the app themselves. When they deliver, mark the work Done from its ⋮ menu, and record what they charged.',
            'لا يستطيع الشريك تحديث التطبيق بنفسه. عندما يسلّم، علّم العمل كمنجز من قائمة ⋮ الخاصة به، وسجّل ما تقاضاه.',
          )),
        ],
      ),
      HelpArticle(
        id: 'owntask',
        audience: HelpAudience.doers,
        title: Bi('Adding your own task', 'إضافة مهمة لنفسك'),
        blocks: [
          HelpSteps([
            Bi('Open the request and click Add my task in the Work panel.',
                'افتح الطلب واضغط «إضافة مهمة لي» في لوحة «الأعمال».'),
            Bi('Describe what you’re doing, choose the kind of work and, if it’s for one product, which one.',
                'صِف ما ستقوم به، واختر نوع العمل، والمنتج إن كان لمنتج واحد.'),
            Bi('Click Add. The task is yours and appears in My work.',
                'اضغط «إضافة». تصبح المهمة لك وتظهر في «مهامي».'),
          ]),
        ],
      ),
    ],
  ),

  // ---------------------------------------------------------------- money
  HelpSection(
    id: 'money',
    title: Bi('Prices and payments', 'الأسعار والمدفوعات'),
    icon: Icons.payments_outlined,
    articles: [
      HelpArticle(
        id: 'quote',
        audience: HelpAudience.money,
        title: Bi('Pricing a request', 'تسعير الطلب'),
        blocks: [
          HelpText(Bi(
            'A quotation records the price you gave the customer — by phone, in person or any other way. Nothing is sent from the app.',
            'عرض السعر يسجّل السعر الذي أبلغت به العميل — بالهاتف أو شخصيًا أو بأي طريقة. لا يُرسل التطبيق أي شيء.',
          )),
          HelpSteps([
            Bi('Open the request and click Price the work in the Quotations panel.',
                'افتح الطلب واضغط «تسعير العمل» في لوحة «عروض الأسعار».'),
            Bi('Enter a unit price for each product. Leave one blank to price it separately later.',
                'أدخل سعر الوحدة لكل منتج. اترك منتجًا فارغًا لتسعيره لاحقًا بشكل منفصل.'),
            Bi('Add a discount if there is one. The total is shown at the bottom.',
                'أضف خصمًا إن وُجد. يظهر الإجمالي في الأسفل.'),
            Bi('Click Create. It starts as a Draft — if you spot a mistake before telling the customer, click Edit on it.',
                'اضغط «إنشاء». يبدأ العرض كمسودة — إذا لاحظت خطأ قبل إبلاغ العميل، اضغط «تعديل» عليه.'),
            Bi('Once you’ve told the customer, click Told the customer.',
                'بعد إبلاغ العميل، اضغط «أُبلغ العميل».'),
            Bi('When they answer, click Approved or Rejected.',
                'عندما يرد، اضغط «وافق» أو «رفض».'),
          ]),
          HelpTip(Bi(
            'Approving a quotation marks its products as approved, and its total becomes what the customer owes.',
            'اعتماد عرض السعر يجعل منتجاته معتمدة، ويصبح إجماليه هو المستحق على العميل.',
          )),
        ],
      ),
      HelpArticle(
        id: 'revise',
        audience: HelpAudience.money,
        title: Bi('Changing a price', 'تعديل السعر'),
        blocks: [
          HelpText(Bi(
            'A quotation is never edited. Once it has been told to the customer, click Revise to make the next version — v2, v3 and so on — with the new prices.',
            'عرض السعر لا يُعدَّل أبدًا. بعد إبلاغ العميل به، اضغط «مراجعة» لإنشاء النسخة التالية — v2 ثم v3 وهكذا — بالأسعار الجديدة.',
          )),
          HelpText(Bi(
            'The earlier version stays on the page, marked Superseded, so you can always see how the price was reached.',
            'تبقى النسخة السابقة في الصفحة بعلامة «مُستبدل»، فيمكنك دائمًا رؤية كيف وصلتم إلى السعر.',
          )),
        ],
      ),
      HelpArticle(
        id: 'payment',
        audience: HelpAudience.money,
        title: Bi('Recording a payment', 'تسجيل دفعة'),
        blocks: [
          HelpSteps([
            Bi('Open the request and click Record payment in the Payments panel.',
                'افتح الطلب واضغط «تسجيل دفعة» في لوحة «المدفوعات».'),
            Bi('Enter the amount and how it was paid: cash, online, bank transfer or cheque.',
                'أدخل المبلغ وطريقة الدفع: نقدًا، أو إلكترونيًا، أو تحويلًا بنكيًا، أو شيكًا.'),
            Bi('Choose what it is — a down payment, a partial payment or the final payment — and add the receipt or transfer number if there is one.',
                'اختر نوعها — دفعة مقدمة، أو جزئية، أو نهائية — وأضف رقم الإيصال أو التحويل إن وُجد.'),
            Bi('Click Record and confirm.', 'اضغط «تسجيل» ثم أكّد.'),
          ]),
          HelpTip(Bi(
            'A payment can’t be edited or deleted once it’s recorded, so check the amount before you confirm. If one goes in wrong, tell the owner.',
            'لا يمكن تعديل الدفعة أو حذفها بعد تسجيلها، لذلك تأكد من المبلغ قبل التأكيد. إذا سُجّلت دفعة بشكل خاطئ، أبلغ المالك.',
          )),
        ],
      ),
      HelpArticle(
        id: 'moneypanel',
        audience: HelpAudience.money,
        title: Bi('Reading the Money panel', 'قراءة لوحة المال'),
        blocks: [
          HelpList([
            Bi('Approved — the total of the approved quotations.',
                'المعتمد — إجمالي عروض الأسعار المعتمدة.'),
            Bi('Paid — everything received so far.',
                'المدفوع — كل ما تم استلامه حتى الآن.'),
            Bi('Balance — what the customer still owes.',
                'المتبقي — ما يزال على العميل.'),
          ]),
          HelpText(Bi(
            'If money comes in before anything has been approved, it shows as paid in advance and there’s no balance yet.',
            'إذا وصل مبلغ قبل اعتماد أي شيء، يظهر كمدفوع مقدمًا ولا يكون هناك رصيد متبقٍ بعد.',
          )),
        ],
      ),
      HelpArticle(
        id: 'whosees',
        audience: HelpAudience.money,
        title: Bi('Who can see prices', 'من يستطيع رؤية الأسعار'),
        blocks: [
          HelpText(Bi(
            'Only the owner and supervisors see quotations, payments, the Money panel and Reports. Designers and production never see prices — not on the request page and not in the History.',
            'المالك والمشرفون فقط يرون عروض الأسعار والمدفوعات ولوحة المال والتقارير. المصممون وفريق الإنتاج لا يرون الأسعار أبدًا — لا في صفحة الطلب ولا في السجل.',
          )),
        ],
      ),
    ],
  ),

  // ------------------------------------------------------------ customers
  HelpSection(
    id: 'customers',
    title: Bi('Customers', 'العملاء'),
    icon: Icons.people_outline_rounded,
    articles: [
      HelpArticle(
        id: 'find',
        title: Bi('Finding a customer', 'البحث عن عميل'),
        blocks: [
          HelpText(Bi(
            'On the Customers screen, type part of a name, a company or a phone number. Phone numbers can be typed any way — with or without spaces, dashes or +974.',
            'في شاشة «العملاء»، اكتب جزءًا من الاسم أو الشركة أو رقم الهاتف. يمكن كتابة الرقم بأي طريقة — بمسافات أو شرطات أو بدونها، ومع ‎+974 أو بدونها.',
          )),
        ],
      ),
      HelpArticle(
        id: 'add',
        title: Bi('Adding or changing a customer', 'إضافة عميل أو تعديله'),
        blocks: [
          HelpSteps([
            Bi('On the Customers screen, click New customer.',
                'في شاشة «العملاء»، اضغط «عميل جديد».'),
            Bi('Enter their name — the only thing required — and the phone, company, email and notes if you have them.',
                'أدخل الاسم — وهو الحقل المطلوب الوحيد — والهاتف والشركة والبريد والملاحظات إن توفرت.'),
            Bi('Click Save.', 'اضغط «حفظ».'),
          ]),
          HelpText(Bi(
            'If the phone number already belongs to another customer, a warning shows who. It’s only a warning — a company switchboard or a family business can share a number — but check you’re not adding the same customer twice.',
            'إذا كان رقم الهاتف مستخدمًا لعميل آخر، يظهر تنبيه باسمه. إنه تنبيه فقط — فقد يشترك مقسم شركة أو عمل عائلي في رقم واحد — لكن تأكد أنك لا تضيف العميل نفسه مرتين.',
          )),
          HelpTip(Bi(
            'The owner, supervisors and designers can add customers. Only the owner and supervisors can change a customer’s details — click the pencil icon on their row.',
            'يمكن للمالك والمشرفين والمصممين إضافة عملاء. أما تعديل بيانات العميل فللمالك والمشرفين فقط — اضغط أيقونة القلم في صفه.',
          )),
        ],
      ),
    ],
  ),

  // -------------------------------------------------------------- reports
  HelpSection(
    id: 'reports',
    title: Bi('Reports', 'التقارير'),
    icon: Icons.table_chart_outlined,
    articles: [
      HelpArticle(
        id: 'export',
        audience: HelpAudience.money,
        title: Bi('Exporting to Excel', 'التصدير إلى Excel'),
        blocks: [
          HelpSteps([
            Bi('Open Reports from the sidebar.',
                'افتح «التقارير» من الشريط الجانبي.'),
            Bi('Choose a date range — or Everything — and, if you like, one stage or one supervisor.',
                'اختر الفترة — أو «كل شيء» — ويمكنك اختيار مرحلة واحدة أو مشرف واحد.'),
            Bi('Click Create the workbook.', 'اضغط «إنشاء الملف».'),
            Bi('Click Show in folder to find the file.',
                'اضغط «إظهار في المجلد» للوصول إلى الملف.'),
          ]),
          HelpText(Bi(
            'Workbooks are saved in your Documents folder, inside Inmore. Each has two sheets: Items, with one row for each product, and Requests, with one row for each request and its total, what has been paid and the balance.',
            'تُحفظ الملفات في مجلد «المستندات» داخل مجلد Inmore. في كل ملف ورقتان: المنتجات، بصف لكل منتج، والطلبات، بصف لكل طلب مع الإجمالي والمدفوع والمتبقي.',
          )),
          HelpTip(Bi(
            'To add up totals or payments, use the Requests sheet — each request appears there exactly once. The workbook is always in English.',
            'لجمع الإجماليات أو المدفوعات، استخدم ورقة الطلبات — فكل طلب يظهر فيها مرة واحدة فقط. الملف دائمًا باللغة الإنجليزية.',
          )),
        ],
      ),
    ],
  ),
];
