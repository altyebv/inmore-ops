import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

import '../../shell/tour.dart';

/// Which stage tab is open. Filtered here rather than in the query, so every
/// tab can show its count from one fetch.
final _stageProvider = StateProvider<RequestStatus?>((ref) => null);

enum _Sort { newest, due, number }

final _sortProvider = StateProvider<_Sort>((ref) => _Sort.newest);

/// The supervisor's landing screen.
///
/// Blocked and overdue requests are pulled to the top: the first question on
/// walking in is "what needs me", not "what exists".
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final board = ref.watch(boardProvider);
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    final all = board.valueOrNull;
    final openCount = all?.where((r) => r.status.isOpen).length;

    return Column(
      children: [
        PageHeader(
          title: l.boardTitle,
          subtitle: openCount == null ? null : l.boardSubtitle(openCount),
          actions: [
            IconButton(
              tooltip: '${l.refresh}  (F5)',
              onPressed: () => ref.invalidate(boardProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
            if (me?.role.canManageRequests ?? false)
              KeyedSubtree(
                key: TourKeys.newRequest,
                child: FilledButton.icon(
                  onPressed: () => context.go('/requests/new'),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l.newRequest),
                ),
              ),
          ],
          bottom: _Filters(requests: all ?? const []),
        ),
        Expanded(
          child: AsyncView(
            value: board,
            onRetry: () => ref.invalidate(boardProvider),
            loading: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SkeletonList(rows: 8),
            ),
            builder: (requests) => _Body(requests: requests),
          ),
        ),
      ],
    );
  }
}

class _Filters extends ConsumerStatefulWidget {
  const _Filters({required this.requests});

  final List<RequestSummary> requests;

  @override
  ConsumerState<_Filters> createState() => _FiltersState();
}

class _FiltersState extends ConsumerState<_Filters> {
  late final _search =
      TextEditingController(text: ref.read(boardFilterProvider).search);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref
          .read(boardFilterProvider.notifier)
          .update((f) => f.copyWith(search: v));
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final filter = ref.watch(boardFilterProvider);
    final stage = ref.watch(_stageProvider);
    final sort = ref.watch(_sortProvider);
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    final tokens = context.tokens;

    // "Clear filters" resets the provider; keep the box in step with it.
    ref.listen(boardFilterProvider, (_, next) {
      if ((next.search ?? '').isEmpty && _search.text.isNotEmpty) {
        _debounce?.cancel();
        _search.clear();
      }
    });

    final counts = <RequestStatus, int>{};
    for (final r in widget.requests) {
      counts[r.status] = (counts[r.status] ?? 0) + 1;
    }
    final stages = [
      ...RequestStatus.pipeline,
      if (!filter.openOnly) ...[
        RequestStatus.completed,
        RequestStatus.cancelled,
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  hintText: l.boardSearchHint,
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l.clear,
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () {
                            _search.clear();
                            _onSearch('');
                          },
                        ),
                ),
              ),
            ),
            const Spacer(),
            if (me != null)
              FilterChip(
                label: Text(l.filterMine),
                selected: filter.supervisorId == me.id,
                onSelected: (on) => ref
                    .read(boardFilterProvider.notifier)
                    .update((f) => on
                        ? f.copyWith(supervisorId: me.id)
                        : f.copyWith(clearSupervisor: true)),
              ),
            const SizedBox(width: Space.sm),
            FilterChip(
              label: Text(l.includeClosed),
              selected: !filter.openOnly,
              onSelected: (on) {
                ref
                    .read(boardFilterProvider.notifier)
                    .update((f) => f.copyWith(openOnly: !on));
                if (!on && (stage?.isTerminal ?? false)) {
                  ref.read(_stageProvider.notifier).state = null;
                }
              },
            ),
            const SizedBox(width: Space.sm),
            PopupMenuButton<_Sort>(
              tooltip: l.sortBy,
              initialValue: sort,
              onSelected: (s) => ref.read(_sortProvider.notifier).state = s,
              itemBuilder: (_) => [
                PopupMenuItem(value: _Sort.newest, child: Text(l.sortNewest)),
                PopupMenuItem(value: _Sort.due, child: Text(l.sortDue)),
                PopupMenuItem(value: _Sort.number, child: Text(l.sortNumber)),
              ],
              child: Padding(
                padding: const EdgeInsets.all(Space.sm),
                child: Row(
                  children: [
                    const Icon(Icons.sort_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text(
                        switch (sort) {
                          _Sort.newest => l.sortNewest,
                          _Sort.due => l.sortDue,
                          _Sort.number => l.sortNumber,
                        },
                        style: context.text.labelLarge),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _StageTab(
                label: l.all,
                count: widget.requests.length,
                selected: stage == null,
                onTap: () => ref.read(_stageProvider.notifier).state = null,
              ),
              for (final s in stages)
                _StageTab(
                  label: s.tr(l),
                  count: counts[s] ?? 0,
                  colour: tokens.stage(s),
                  selected: stage == s,
                  onTap: () => ref.read(_stageProvider.notifier).state = s,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StageTab extends StatelessWidget {
  const _StageTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.colour,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: Material(
        color: selected ? c.primary : c.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? c.primary : c.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (colour != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: colour, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                ],
                Text(label,
                    style: context.text.labelLarge?.copyWith(
                      color: selected ? c.onPrimary : c.onSurface,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(width: 6),
                Text('$count',
                    style: context.text.labelMedium?.copyWith(
                      color: selected
                          ? c.onPrimary.withValues(alpha: 0.7)
                          : c.onSurfaceVariant,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.requests});

  final List<RequestSummary> requests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final stage = ref.watch(_stageProvider);
    final sort = ref.watch(_sortProvider);
    final filter = ref.watch(boardFilterProvider);

    if (requests.isEmpty &&
        (filter.search ?? '').isEmpty &&
        filter.supervisorId == null) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: l.noRequestsYet,
        body: l.noRequestsYetBody,
      );
    }

    final shown = [
      for (final r in requests)
        if (stage == null || r.status == stage) r,
    ];
    if (shown.isEmpty) {
      return EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: l.noRequestsMatch,
        body: l.noRequestsMatchBody,
        action: OutlinedButton(
          onPressed: () {
            ref.read(_stageProvider.notifier).state = null;
            ref.read(boardFilterProvider.notifier).state = const BoardFilter();
          },
          child: Text(l.clearFilters),
        ),
      );
    }

    switch (sort) {
      case _Sort.newest:
        break; // the query's own order
      case _Sort.number:
        shown.sort((a, b) => b.number.compareTo(a.number));
      case _Sort.due:
        shown.sort((a, b) {
          if (a.neededBy == null) return b.neededBy == null ? 0 : 1;
          if (b.neededBy == null) return -1;
          return a.neededBy!.compareTo(b.neededBy!);
        });
    }

    final attention = shown.where((r) => r.needsAttention).toList();
    final rest = shown.where((r) => !r.needsAttention).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 1000;
        return ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
          children: [
            Card(
              child: Column(
                children: [
                  _HeaderRow(wide: wide),
                  if (attention.isNotEmpty) ...[
                    _GroupRow(
                      label: l.needsAttention,
                      count: attention.length,
                      colour: context.colors.error,
                    ),
                    for (final r in attention) _RequestRow(r, wide: wide),
                  ],
                  if (rest.isNotEmpty) ...[
                    if (attention.isNotEmpty)
                      _GroupRow(label: l.everythingElse, count: rest.length),
                    for (final r in rest) _RequestRow(r, wide: wide),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Cols {
  static const ref = 76.0;
  static const stage = 160.0;
  static const supervisor = 160.0;
  static const items = 84.0;
  static const due = 104.0;
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = context.text.labelMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: _Cols.ref, child: Text(l.colRequest, style: style)),
          Expanded(flex: 4, child: Text(l.customer, style: style)),
          SizedBox(width: _Cols.stage, child: Text(l.colStage, style: style)),
          const Expanded(flex: 3, child: SizedBox()),
          if (wide) ...[
            SizedBox(
              width: _Cols.supervisor,
              child: Text(l.colSupervisor, style: style),
            ),
            SizedBox(width: _Cols.items, child: Text(l.colItems, style: style)),
          ],
          SizedBox(width: _Cols.due, child: Text(l.colDue, style: style)),
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.label, required this.count, this.colour});

  final String label;
  final int count;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = colour ?? c.onSurfaceVariant;
    return Container(
      width: double.infinity,
      color: c.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 7),
      child: Row(
        children: [
          if (colour != null) ...[
            Icon(Icons.priority_high_rounded, size: 15, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label, style: context.text.labelMedium?.copyWith(color: fg)),
          const SizedBox(width: Space.sm),
          Text('$count',
              style: context.text.labelMedium?.copyWith(
                color: c.onSurfaceVariant,
              )),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow(this.request, {required this.wide});

  final RequestSummary request;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    final t = context.tokens;
    final r = request;

    return Column(
      children: [
        const Divider(),
        InkWell(
          onTap: () => context.go('/requests/${r.id}'),
          hoverColor: c.onSurface.withValues(alpha: 0.035),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: _Cols.ref,
                  child: Text(r.reference, style: context.text.titleSmall),
                ),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserText(r.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500)),
                      if (r.title != null)
                        UserText(r.title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall),
                    ],
                  ),
                ),
                SizedBox(
                  width: _Cols.stage,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: StatusBadge(r.status.tr(l),
                        color: t.stage(r.status), dot: true),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (r.waitingOn != null)
                        StatusBadge(r.waitingOn!.tr(l),
                            color: t.danger,
                            icon: Icons.pause_circle_outline_rounded),
                      if (r.isOverdue)
                        StatusBadge(l.flagOverdue,
                            color: t.danger, icon: Icons.schedule_rounded),
                      if (r.needsSupervisor)
                        StatusBadge(l.flagNoSupervisor,
                            color: t.warning, icon: Icons.person_off_outlined),
                    ],
                  ),
                ),
                if (wide) ...[
                  SizedBox(
                    width: _Cols.supervisor,
                    child: r.supervisorName == null
                        ? Text('—', style: context.text.bodySmall)
                        : Row(
                            children: [
                              InitialsAvatar(r.supervisorName!, size: 24),
                              const SizedBox(width: Space.sm),
                              Expanded(
                                child: UserText(r.supervisorName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.bodySmall
                                        ?.copyWith(color: c.onSurface)),
                              ),
                            ],
                          ),
                  ),
                  SizedBox(
                    width: _Cols.items,
                    child: Text(l.itemsCount(r.itemCount),
                        style: context.text.bodySmall),
                  ),
                ],
                SizedBox(
                  width: _Cols.due,
                  child: Text(
                    r.neededBy == null ? '—' : Fmt.dayMonth(r.neededBy),
                    style: context.text.bodySmall?.copyWith(
                      color: r.isOverdue ? t.danger : c.onSurface,
                      fontWeight: r.isOverdue ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
