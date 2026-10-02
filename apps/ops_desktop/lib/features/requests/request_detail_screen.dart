import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

import 'money_panels.dart';
import 'panels.dart';
import 'timeline_panel.dart';

/// Everything about one request on one screen: what was asked for, who is
/// doing it, what it was priced at, what has been paid, and the full history.
///
/// Wide windows get two columns — the work on the left, the facts and the
/// story on the right — so a supervisor can price a job with its history in
/// view. Narrow windows stack them.
class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(requestProvider(requestId));

    return AsyncView(
      value: request,
      onRetry: () => refreshRequest(ref, requestId),
      loading: const _Skeleton(),
      builder: (r) => _Detail(request: r),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.request});

  final RequestSummary request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    final canSeeMoney = me?.role.canSeeMoney ?? false;
    final canManage = me?.role.canManageRequests ?? false;
    final r = request;

    final flags = [
      if (r.isOverdue)
        StatusBadge(l.flagOverdue,
            color: t.danger, icon: Icons.schedule_rounded),
      if (r.needsSupervisor)
        StatusBadge(l.flagNoSupervisor,
            color: t.warning, icon: Icons.person_off_outlined),
      if (r.status.isTerminal)
        StatusBadge(r.status.tr(l), color: t.stage(r.status), dot: true),
    ];

    return Column(
      children: [
        PageHeader(
          leading: BackButton(onPressed: () => context.go('/')),
          title: '${r.reference}  ·  ${r.customerName}',
          subtitle: [
            if (r.title != null) r.title!,
            l.requestFrom(r.source.tr(l)),
          ].join('  ·  '),
          actions: [
            ...flags,
            IconButton(
              tooltip: '${l.refresh}  (F5)',
              onPressed: () => refreshRequest(ref, r.id),
              icon: const Icon(Icons.refresh_rounded),
            ),
            if (canManage && r.status.isOpen)
              MenuAnchor(
                menuChildren: [
                  MenuItemButton(
                    leadingIcon: Icon(Icons.block_rounded,
                        size: 18, color: context.colors.error),
                    onPressed: () => cancelRequestFlow(context, ref, r),
                    child: Text(l.cancelRequest,
                        style: TextStyle(color: context.colors.error)),
                  ),
                ],
                builder: (context, controller, _) => IconButton(
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                  icon: const Icon(Icons.more_vert_rounded),
                ),
              ),
          ],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1120;
              const gap = SizedBox(height: Space.lg);

              final work = [
                ItemsPanel(request: r, canManage: canManage),
                gap,
                TasksPanel(request: r, canManage: canManage),
                if (canSeeMoney) ...[
                  gap,
                  QuotationsPanel(request: r),
                  gap,
                  PaymentsPanel(request: r),
                ],
              ];
              final facts = [
                DetailsPanel(request: r, canManage: canManage),
                if (canSeeMoney) ...[gap, MoneyPanel(requestId: r.id)],
              ];
              final story = [TimelinePanel(requestId: r.id)];

              return SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StageCard(request: r, canManage: canManage),
                        gap,
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: work,
                                ),
                              ),
                              const SizedBox(width: Space.lg),
                              SizedBox(
                                width: 380,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [...facts, gap, ...story],
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [...facts, gap, ...work, gap, ...story],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The detail page's outline while the first load is in flight.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: Padding(
        padding: EdgeInsets.fromLTRB(28, 28, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 320, height: 24),
            SizedBox(height: 10),
            SkeletonBox(width: 220, height: 14),
            SizedBox(height: 28),
            SkeletonBox(height: 96, radius: Radii.lg),
            SizedBox(height: Space.lg),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        SkeletonBox(height: 180, radius: Radii.lg),
                        SizedBox(height: Space.lg),
                        SkeletonBox(height: 140, radius: Radii.lg),
                      ],
                    ),
                  ),
                  SizedBox(width: Space.lg),
                  SizedBox(
                    width: 380,
                    child: SkeletonBox(height: 260, radius: Radii.lg),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
