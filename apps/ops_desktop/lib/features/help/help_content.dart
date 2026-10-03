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
  doers,

  /// Everyone but designers: they record stock coming in and going out.
  stock;

  bool allows(Employee e) => switch (this) {
        everyone => true,
        managers => e.role.canManageRequests,
        money => e.role.canSeeMoney,
        doers => !e.role.canManageRequests,
        stock => e.role != EmployeeRole.designer,
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

  // -------------------------------------------------------------- inventory
  HelpSection(
    id: 'inventory',
    title: Bi('Inventory', 'المخزون'),
    icon: Icons.inventory_2_outlined,
    articles: [
      HelpArticle(
        id: 'stocklist',
        title: Bi('What’s in stock', 'ما هو متوفر في المخزون'),
        blocks: [
          HelpText(Bi(
            'Inventory lists the materials the shop keeps, how many are on hand and where they are kept. Items at or below their reorder level show Low; items with none left show Out.',
            'يعرض «المخزون» المواد التي يحتفظ بها المحل، والكمية المتوفرة منها ومكان تخزينها. الأصناف التي تصل إلى حد إعادة الطلب أو تقل عنه تظهر عليها «منخفض»، والتي نفدت تظهر عليها «نفد».',
          )),
          HelpText(Bi(
            'Click an item to see its history: every time stock came in, went out or was counted, with who did it.',
            'اضغط على أي صنف لترى سجله: كل مرة دخل فيها مخزون أو خرج أو جُرد، ومن قام بذلك.',
          )),
          HelpTip(Bi(
            'Stock isn’t linked to requests yet. Record what you use by hand when you take it out.',
            'المخزون غير مرتبط بالطلبات بعد. سجّل ما تستخدمه يدويًا عند صرفه.',
          )),
        ],
      ),
      HelpArticle(
        id: 'stockmove',
        audience: HelpAudience.stock,
        title: Bi('Recording stock in and out', 'تسجيل الاستلام والصرف'),
        blocks: [
          HelpSteps([
            Bi('Find the item in Inventory.', 'ابحث عن الصنف في «المخزون».'),
            Bi('Click the green + to receive stock, or the − to take some out.',
                'اضغط + الأخضر للاستلام، أو − للصرف.'),
            Bi('Enter the quantity and, if you like, a note: who it came from, or what it was for.',
                'أدخل الكمية، ويمكنك إضافة ملاحظة: من أين جاء، أو لأي غرض صُرف.'),
            Bi('Click Record.', 'اضغط «تسجيل».'),
          ]),
          HelpText(Bi(
            'A recorded movement can’t be edited. If you made a mistake, record the opposite, or ask a supervisor to do a stock count.',
            'لا يمكن تعديل حركة بعد تسجيلها. إذا أخطأت، سجّل العكس، أو اطلب من المشرف إجراء جرد.',
          )),
        ],
      ),
      HelpArticle(
        id: 'stockmanage',
        audience: HelpAudience.managers,
        title:
            Bi('Adding items and counting stock', 'إضافة الأصناف وجرد المخزون'),
        blocks: [
          HelpList([
            Bi('Add an item: click Add item and enter its name, unit and reorder level. The unit cost is optional, and only the owner and supervisors see it.',
                'إضافة صنف: اضغط «إضافة صنف» وأدخل الاسم والوحدة وحد إعادة الطلب. تكلفة الوحدة اختيارية، ولا يراها إلا المالك والمشرفون.'),
            Bi('Count stock: from the item’s ⋮ menu choose Stock count, and enter what is actually on the shelf. The difference is recorded.',
                'الجرد: من قائمة ⋮ الخاصة بالصنف اختر «جرد»، وأدخل الكمية الموجودة فعلًا. يُسجَّل الفرق.'),
            Bi('Stop using an item: choose Archive. Its history stays; turn on Show archived to see it again.',
                'إيقاف استخدام صنف: اختر «أرشفة». يبقى سجله، وفعّل «إظهار المؤرشفة» لتراه مجددًا.'),
          ]),
        ],
      ),
    ],
  ),

  // -------------------------------------------------------------- expenses
  HelpSection(
    id: 'expenses',
    title: Bi('Expenses', 'المصروفات'),
    icon: Icons.receipt_long_outlined,
    articles: [
      HelpArticle(
        id: 'addexpense',
        audience: HelpAudience.money,
        title: Bi('Recording an expense', 'تسجيل مصروف'),
        blocks: [
          HelpSteps([
            Bi('Open Expenses and click Add expense.',
                'افتح «المصروفات» واضغط «إضافة مصروف».'),
            Bi('Enter the date, the amount and a category, such as Rent or Materials. Categories you’ve used before are suggested.',
                'أدخل التاريخ والمبلغ والفئة، مثل «إيجار» أو «مواد». تُقترح الفئات التي استخدمتها من قبل.'),
            Bi('Add who it was paid to and how, if you like.',
                'أضف المدفوع له وطريقة الدفع إن أردت.'),
            Bi('For a cost that repeats every month, like rent or salaries, turn on Monthly fixed cost.',
                'للمصروف الذي يتكرر كل شهر، مثل الإيجار أو الرواتب، فعّل «مصروف شهري ثابت».'),
          ]),
          HelpText(Bi(
            'The top of the page shows the month’s spending, the payments received and the difference. Use the arrows to move between months.',
            'يعرض أعلى الصفحة مصروفات الشهر والمدفوعات المستلمة والفرق بينهما. استخدم الأسهم للتنقل بين الأشهر.',
          )),
        ],
      ),
      HelpArticle(
        id: 'monthly',
        audience: HelpAudience.money,
        title: Bi('Monthly costs', 'المصروفات الشهرية'),
        blocks: [
          HelpText(Bi(
            'At the start of a month, click Copy monthly costs. Last month’s monthly costs are listed with their amounts. Change any that are different, untick any that don’t apply, then click Add.',
            'في بداية الشهر، اضغط «نسخ المصروفات الشهرية». تظهر مصروفات الشهر الماضي الشهرية بمبالغها. غيّر ما اختلف منها، وألغِ تحديد ما لا ينطبق، ثم اضغط «إضافة».',
          )),
        ],
      ),
      HelpArticle(
        id: 'fixexpense',
        audience: HelpAudience.money,
        title: Bi('Correcting an expense', 'تصحيح مصروف'),
        blocks: [
          HelpText(Bi(
            'Click an expense to edit it. If it shouldn’t be there at all, choose Void from its ⋮ menu and say why. A voided expense stays on record, crossed out, and stops counting in totals. Turn on Show voided to see them.',
            'اضغط على المصروف لتعديله. وإن لم يكن يجب تسجيله أصلًا، اختر «إلغاء» من قائمة ⋮ واذكر السبب. يبقى المصروف الملغى في السجل مشطوبًا، ولا يُحتسب في الإجماليات. فعّل «إظهار الملغاة» لرؤيتها.',
          )),
          HelpTip(Bi(
            'Expenses can’t be deleted, and every change is kept in the history, so the owner can always see what happened.',
            'لا يمكن حذف المصروفات، وكل تغيير يبقى في السجل، ليتمكن المالك دائمًا من معرفة ما حدث.',
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
        id: 'reportsuse',
        audience: HelpAudience.money,
        title: Bi('Looking at a report', 'الاطلاع على تقرير'),
        blocks: [
          HelpSteps([
            Bi('Open Reports and choose one along the top: sales by product, requests, payments received, expenses, stock, or income vs expenses.',
                'افتح «التقارير» واختر واحدًا من الأعلى: المبيعات حسب المنتج، أو الطلبات، أو المدفوعات المستلمة، أو المصروفات، أو المخزون، أو الإيرادات مقابل المصروفات.'),
            Bi('Choose the date range, and a stage or supervisor where offered.',
                'اختر الفترة، والمرحلة أو المشرف عند توفرهما.'),
          ]),
          HelpList([
            Bi('Click a column heading to sort by it; click again to reverse.',
                'اضغط عنوان العمود للترتيب حسبه، واضغط مرة أخرى لعكس الترتيب.'),
            Bi('Group by puts rows together, with a subtotal for each group.',
                '«تجميع حسب» يجمع الصفوف معًا، مع مجموع فرعي لكل مجموعة.'),
            Bi('Columns lets you choose which columns show, and their order.',
                '«الأعمدة» يتيح لك اختيار الأعمدة الظاهرة وترتيبها.'),
            Bi('To leave a row out, point at it and click the eye. Put back brings them all back.',
                'لاستبعاد صف، مرّر المؤشر عليه واضغط أيقونة العين. «إعادتها» تعيدها كلها.'),
            Bi('Click the title to rename the report, and add a note under it if you like.',
                'اضغط العنوان لتغيير اسم التقرير، ويمكنك إضافة ملاحظة تحته.'),
          ]),
          HelpTip(Bi(
            'Shaping a report never changes the records. To correct a figure, fix it where it lives: on the request, or in Expenses.',
            'تنظيم التقرير لا يغيّر السجلات أبدًا. لتصحيح رقم، صحّحه في مكانه: في الطلب، أو في «المصروفات».',
          )),
        ],
      ),
      HelpArticle(
        id: 'export',
        audience: HelpAudience.money,
        title: Bi('Printing and exporting', 'الطباعة والتصدير'),
        blocks: [
          HelpList([
            Bi('Print opens the printer dialog with the report on Inmore’s letterhead.',
                '«طباعة» يفتح نافذة الطابعة والتقرير على ورق إنمور الرسمي.'),
            Bi('PDF saves the same page as a file.',
                '«PDF» يحفظ الصفحة نفسها كملف.'),
            Bi('Excel → This report, as shown saves the rows you see, with the totals on a second sheet.',
                '«Excel ← هذا التقرير كما يظهر» يحفظ الصفوف الظاهرة، مع الإجماليات في ورقة ثانية.'),
            Bi('Excel → Accountant’s workbook saves every product and every request in the range, unshaped.',
                '«Excel ← ملف المحاسب» يحفظ كل المنتجات وكل الطلبات في الفترة، دون تنظيم.'),
          ]),
          HelpText(Bi(
            'Files are saved in your Documents folder, inside Inmore. Click Show in folder to find the file. Excel files are always in English.',
            'تُحفظ الملفات في مجلد «المستندات» داخل مجلد Inmore. اضغط «إظهار في المجلد» للوصول إلى الملف. ملفات Excel دائمًا باللغة الإنجليزية.',
          )),
          HelpTip(Bi(
            'The letterhead comes from Business details, at the top of Reports: the name, address, phone and CR number.',
            'تأتي بيانات الورق الرسمي من «بيانات المنشأة» أعلى صفحة «التقارير»: الاسم والعنوان والهاتف ورقم السجل التجاري.',
          )),
        ],
      ),
    ],
  ),

  // -------------------------------------------------------------- staff
  HelpSection(
    id: 'staff',
    title: Bi('Staff', 'الموظفون'),
    icon: Icons.badge_outlined,
    articles: [
      HelpArticle(
        id: 'addstaff',
        audience: HelpAudience.managers,
        title: Bi('Adding a staff member', 'إضافة موظف'),
        blocks: [
          HelpSteps([
            Bi('Open Staff and click Add staff member.',
                'افتح «الموظفون» واضغط «إضافة موظف».'),
            Bi('Enter their name, email and role. A temporary password is made for you.',
                'أدخل الاسم والبريد الإلكتروني والدور. تُنشأ كلمة مرور مؤقتة تلقائيًا.'),
            Bi('Click Create, then give them the email and password shown. They can sign in on any office computer.',
                'اضغط «إنشاء»، ثم أعطه البريد الإلكتروني وكلمة المرور الظاهرين. يمكنه تسجيل الدخول من أي جهاز في المكتب.'),
          ]),
          HelpTip(Bi(
            'Forgot their password? From their ⋮ menu choose Reset password, and give them the new one.',
            'نسي كلمة المرور؟ من قائمة ⋮ الخاصة به اختر «إعادة تعيين كلمة المرور»، وأعطه الكلمة الجديدة.',
          )),
        ],
      ),
      HelpArticle(
        id: 'removestaff',
        audience: HelpAudience.managers,
        title: Bi('Changing a role or removing access',
            'تغيير الدور أو إيقاف الوصول'),
        blocks: [
          HelpList([
            Bi('Change a name, phone or role: choose Edit from their ⋮ menu.',
                'تغيير الاسم أو الهاتف أو الدور: اختر «تعديل» من قائمة ⋮.'),
            Bi('Someone leaving: choose Remove access. They can no longer see anything, and their name stays on the work they did. Restore access brings them back.',
                'موظف يغادر: اختر «إيقاف الوصول». لن يتمكن من رؤية أي شيء، ويبقى اسمه على الأعمال التي قام بها. «إعادة الوصول» يعيده.'),
            Bi('An account made by mistake and never used can be deleted with Delete account.',
                'الحساب الذي أُنشئ بالخطأ ولم يُستخدم قط يمكن حذفه بـ«حذف الحساب».'),
          ]),
          HelpTip(Bi(
            'Supervisors can manage everyone except the owner. Nobody can change their own role or remove their own access.',
            'يمكن للمشرفين إدارة الجميع عدا المالك. ولا يمكن لأحد تغيير دوره أو إيقاف وصوله بنفسه.',
          )),
        ],
      ),
    ],
  ),
];
