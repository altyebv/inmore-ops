import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inmore_core/inmore_core.dart';

import '../../widgets/common.dart';
import 'money_panels.dart';
import 'panels.dart';
import 'timeline_panel.dart';

/// Everything about one request on one screen: what was asked for, who is
/// doing it, what it was priced at, what has been paid, and the full history.
class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(requestProvider(requestId));
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    final canSeeMoney = me?.role.canSeeMoney ?? false;
    final canManage = me?.role.canManageRequests ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: AsyncView(
          value: request,
          loading: const SizedBox.shrink(),
          builder: (r) => Text('${r.reference}  ·  ${r.customerName}'),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: () => refreshRequest(ref, requestId),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AsyncView(
        value: request,
        builder: (r) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            RequestHeaderPanel(request: r, canManage: canManage),
            if (canSeeMoney) MoneyPanel(requestId: requestId),
            ItemsPanel(request: r, canManage: canManage),
            TasksPanel(request: r, canManage: canManage),
            if (canSeeMoney) QuotationsPanel(request: r),
            if (canSeeMoney) PaymentsPanel(request: r),
            TimelinePanel(requestId: requestId),
          ],
        ),
      ),
    );
  }
}
