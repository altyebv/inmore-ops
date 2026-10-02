import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

import '../../shell/tour.dart';
import 'help_content.dart';

/// The article open in the help center. Kept while the app is open, so going
/// to try something and coming back lands on the same page.
final helpArticleProvider = StateProvider<String?>((ref) => null);

/// The help center: every topic down the side, the chosen one beside it, and
/// a search across both languages' titles and text (in the reader's own).
///
/// Only shows what the reader's role can do — see [HelpAudience].
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    if (me == null) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context);

    final sections = [
      for (final s in helpFor(me))
        if (s.articles.any((a) => a.matches(_query, locale)))
          (
            s,
            [
              for (final a in s.articles)
                if (a.matches(_query, locale)) a
            ]
          ),
    ];
    final visible = [
      for (final (s, list) in sections)
        for (final a in list) (s, a)
    ];

    final selectedId = ref.watch(helpArticleProvider);
    final current = visible.isEmpty
        ? null
        : visible.firstWhere((v) => '${v.$1.id}/${v.$2.id}' == selectedId,
            orElse: () => visible.first);

    return Column(
      children: [
        PageHeader(
          title: l.helpCenter,
          subtitle: l.helpSubtitle,
          actions: [
            OutlinedButton.icon(
              onPressed: () => startTour(context, ref),
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: Text(l.takeTheTour),
            ),
          ],
          bottom: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: 520,
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  hintText: l.helpSearchHint,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l.clear,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        Expanded(
          child: current == null
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: l.helpNoResults,
                  body: l.helpNoResultsBody,
                )
              : Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 290,
                        child: _Topics(
                          sections: sections,
                          current: current.$2,
                          onPick: (s, a) => ref
                              .read(helpArticleProvider.notifier)
                              .state = '${s.id}/${a.id}',
                        ),
                      ),
                      const SizedBox(width: Space.lg),
                      Expanded(
                        child: _ArticleView(
                          key: ValueKey('${current.$1.id}/${current.$2.id}'),
                          section: current.$1,
                          article: current.$2,
                          next: _after(visible, current),
                          onNext: (s, a) => ref
                              .read(helpArticleProvider.notifier)
                              .state = '${s.id}/${a.id}',
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  static (HelpSection, HelpArticle)? _after(
    List<(HelpSection, HelpArticle)> visible,
    (HelpSection, HelpArticle) current,
  ) {
    final i = visible.indexWhere((v) => v.$2 == current.$2);
    return i >= 0 && i + 1 < visible.length ? visible[i + 1] : null;
  }
}

class _Topics extends StatelessWidget {
  const _Topics({
    required this.sections,
    required this.current,
    required this.onPick,
  });

  final List<(HelpSection, List<HelpArticle>)> sections;
  final HelpArticle current;
  final void Function(HelpSection, HelpArticle) onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      children: [
        for (final (section, articles) in sections) ...[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 12, 8, 6),
            child: Row(
              children: [
                Icon(section.icon, size: 16, color: c.onSurfaceVariant),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(section.title.of(context),
                      style: context.text.labelMedium?.copyWith(
                          color: c.onSurfaceVariant, letterSpacing: 0.3)),
                ),
              ],
            ),
          ),
          for (final a in articles)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Material(
                color: a == current ? c.secondaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.md),
                  onTap: () => onPick(section, a),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(32, 9, 12, 9),
                    child: Text(
                      a.title.of(context),
                      style: context.text.bodyMedium?.copyWith(
                        color:
                            a == current ? c.onSecondaryContainer : c.onSurface,
                        fontWeight:
                            a == current ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ArticleView extends StatelessWidget {
  const _ArticleView({
    required this.section,
    required this.article,
    required this.next,
    required this.onNext,
    super.key,
  });

  final HelpSection section;
  final HelpArticle article;
  final (HelpSection, HelpArticle)? next;
  final void Function(HelpSection, HelpArticle) onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(36, 32, 36, 28),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.title.of(context),
                    style: context.text.labelMedium
                        ?.copyWith(color: c.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(article.title.of(context),
                    style: context.text.headlineSmall),
                const SizedBox(height: Space.lg),
                const SizedBox(width: 64, child: CmykStripe(height: 3, gap: 4)),
                const SizedBox(height: Space.lg),
                for (final block in article.blocks) ...[
                  _Block(block),
                  const SizedBox(height: Space.lg),
                ],
                if (next != null) ...[
                  const Divider(height: Space.xxl),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: () => onNext(next!.$1, next!.$2),
                      // Mirrors itself in Arabic.
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(next!.$2.title.of(context)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block(this.block);

  final HelpBlock block;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = context.text.bodyLarge?.copyWith(height: 1.55);
    return switch (block) {
      HelpText(:final text) => Text(text.of(context), style: body),
      HelpList(:final items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(4, 10, 12, 0),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: c.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(child: Text(item.of(context), style: body)),
                  ],
                ),
              ),
          ],
        ),
      HelpSteps(:final steps) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      margin: const EdgeInsetsDirectional.only(end: 12, top: 1),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Text('${i + 1}',
                          style: context.text.labelMedium?.copyWith(
                              color: c.onSecondaryContainer,
                              fontWeight: FontWeight.w600)),
                    ),
                    Expanded(child: Text(steps[i].of(context), style: body)),
                  ],
                ),
              ),
          ],
        ),
      HelpTip(:final text) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: context.tokens.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 20, color: context.tokens.info),
              const SizedBox(width: Space.md),
              Expanded(child: Text(text.of(context), style: body)),
            ],
          ),
        ),
      HelpKeys(:final keys) => Column(
          children: [
            for (final (k, label) in keys)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(label.of(context), style: body)),
                    KeyCap(k),
                  ],
                ),
              ),
          ],
        ),
    };
  }
}
