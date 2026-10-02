import 'package:flutter/widgets.dart';
import 'package:inmore_core/inmore_core.dart';

import 'gen/l10n.dart';

/// `context.l10n.signIn` instead of `L10n.of(context).signIn`.
extension L10nX on BuildContext {
  L10n get l10n => L10n.of(this);
}

// The enums keep their English `label` for the Excel export, which is always
// English so the workbook reads the same for everyone. Screens use `tr`.

extension RequestStatusTr on RequestStatus {
  String tr(L10n l) => switch (this) {
        RequestStatus.isNew => l.stageNew,
        RequestStatus.quotation => l.stageQuotation,
        RequestStatus.design => l.stageDesign,
        RequestStatus.customerApproval => l.stageCustomerApproval,
        RequestStatus.production => l.stageProduction,
        RequestStatus.delivery => l.stageDelivery,
        RequestStatus.completed => l.stageCompleted,
        RequestStatus.cancelled => l.stageCancelled,
      };
}

extension WaitingReasonTr on WaitingReason {
  String tr(L10n l) => switch (this) {
        WaitingReason.customer => l.waitingCustomer,
        WaitingReason.payment => l.waitingPayment,
        WaitingReason.partner => l.waitingPartner,
        WaitingReason.internal => l.waitingInternal,
      };
}

extension RequestSourceTr on RequestSource {
  String tr(L10n l) => switch (this) {
        RequestSource.supervisor => l.sourceSupervisor,
        RequestSource.designer => l.sourceDesigner,
        RequestSource.website => l.sourceWebsite,
        RequestSource.other => l.sourceOther,
      };
}

extension ItemStatusTr on ItemStatus {
  String tr(L10n l) => switch (this) {
        ItemStatus.pending => l.itemPending,
        ItemStatus.approved => l.itemApproved,
        ItemStatus.rejected => l.itemRejected,
        ItemStatus.cancelled => l.itemCancelled,
      };
}

extension FulfillmentModeTr on FulfillmentMode {
  String tr(L10n l) => switch (this) {
        FulfillmentMode.undecided => l.fulfillmentUndecided,
        FulfillmentMode.internal => l.fulfillmentInternal,
        FulfillmentMode.external => l.fulfillmentExternal,
      };
}

extension QuotationStatusTr on QuotationStatus {
  String tr(L10n l) => switch (this) {
        QuotationStatus.draft => l.quoteDraft,
        QuotationStatus.presented => l.quotePresented,
        QuotationStatus.approved => l.quoteApproved,
        QuotationStatus.rejected => l.quoteRejected,
        QuotationStatus.superseded => l.quoteSuperseded,
      };
}

extension TaskTypeTr on TaskType {
  String tr(L10n l) => switch (this) {
        TaskType.design => l.taskTypeDesign,
        TaskType.prepress => l.taskTypePrepress,
        TaskType.production => l.taskTypeProduction,
        TaskType.external => l.taskTypeExternal,
        TaskType.delivery => l.taskTypeDelivery,
        TaskType.other => l.taskTypeOther,
      };
}

extension TaskStatusTr on TaskStatus {
  String tr(L10n l) => switch (this) {
        TaskStatus.todo => l.taskTodo,
        TaskStatus.inProgress => l.taskInProgress,
        TaskStatus.blocked => l.taskBlocked,
        TaskStatus.done => l.taskDone,
        TaskStatus.cancelled => l.taskCancelled,
      };
}

extension PaymentMethodTr on PaymentMethod {
  String tr(L10n l) => switch (this) {
        PaymentMethod.cash => l.methodCash,
        PaymentMethod.online => l.methodOnline,
        PaymentMethod.bankTransfer => l.methodBankTransfer,
        PaymentMethod.cheque => l.methodCheque,
      };
}

extension PaymentKindTr on PaymentKind {
  String tr(L10n l) => switch (this) {
        PaymentKind.downPayment => l.kindDownPayment,
        PaymentKind.partial => l.kindPartial,
        PaymentKind.settlement => l.kindFinal,
      };
}

extension EmployeeRoleTr on EmployeeRole {
  String tr(L10n l) => switch (this) {
        EmployeeRole.owner => l.roleOwner,
        EmployeeRole.supervisor => l.roleSupervisor,
        EmployeeRole.designer => l.roleDesigner,
        EmployeeRole.production => l.roleProduction,
      };
}

extension TimeWords on L10n {
  /// "Today, 14:30" / "Yesterday, 09:05" / "3 Feb 2026, 09:05" — timelines
  /// read better with the recent entries relative.
  String stamp(DateTime d) {
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return todayAt(Fmt.time(d));
    if (diff == 1) return yesterdayAt(Fmt.time(d));
    return Fmt.dateTime(d);
  }

  /// "6 days" / "4h" / "25m" — durations people actually say out loud.
  String duration(Duration? d) {
    if (d == null) return '—';
    if (d.inDays >= 1) return durationDays(d.inDays);
    if (d.inHours >= 1) return durationHours(d.inHours);
    return durationMinutes(d.inMinutes < 1 ? 1 : d.inMinutes);
  }

  /// "3 days ago" / "just now".
  String ago(DateTime from) {
    final d = DateTime.now().difference(from);
    if (d.inMinutes < 1) return justNow;
    return agoFormat(duration(d));
  }
}

/// Turn an activity row into a sentence, in the reader's language.
///
/// Lives in the shared UI package so the desktop app and the owner's phone
/// describe the same event with the same words. Two copies would drift, and
/// then the owner and the supervisor would be reading different accounts of
/// the same job.
///
/// Reads the stored `from`/`to` rather than re-deriving anything: the log is
/// the record, and a description that disagrees with it would be worse than a
/// terse one. Money is appended after a separator rather than spliced into
/// the sentence, so word order never has to change around a number.
String activityDescription(ActivityEntry e, L10n l) {
  final money = num.tryParse('${e.metadata['amount']}');
  String withMoney(String s) => money == null ? s : '$s · ${Fmt.money(money)}';

  String stage(String? wire) {
    if (wire == null) return '—';
    try {
      return RequestStatus.fromWire(wire).tr(l);
    } on ArgumentError {
      return wire;
    }
  }

  String waiting(String? wire) {
    if (wire == null) return '—';
    try {
      return WaitingReason.fromWire(wire).tr(l);
    } on ArgumentError {
      return wire;
    }
  }

  String taskStatus(String? wire) {
    if (wire == null) return '—';
    try {
      return TaskStatus.fromWire(wire).tr(l);
    } on ArgumentError {
      return wire;
    }
  }

  String itemDecision(String? wire) {
    if (wire == null) return '—';
    try {
      return ItemStatus.fromWire(wire).tr(l);
    } on ArgumentError {
      return wire;
    }
  }

  String method(Object? wire) {
    try {
      return PaymentMethod.fromWire('$wire').tr(l);
    } on ArgumentError {
      return '$wire';
    }
  }

  return switch (e.eventType) {
    'request.created' => l.actRequestCreated,
    'request.status_changed' =>
      l.actStatusChanged(stage(e.fromValue), stage(e.toValue)),
    'request.waiting_set' => l.actWaitingSet(waiting(e.toValue)),
    'request.waiting_cleared' => l.actWaitingCleared,
    'request.supervisor_changed' => l.actSupervisorChanged,
    'request.completed' => l.actCompleted,
    'request.cancelled' =>
      l.actCancelled('${e.metadata['reason'] ?? l.actNoReason}'),
    'request.reopened' => l.actReopened(stage(e.fromValue)),
    'item.added' => l.actItemAdded(e.toValue ?? '—'),
    'item.removed' => l.actItemRemoved(e.fromValue ?? '—'),
    'item.decision_changed' => l.actItemDecision(
        itemDecision(e.toValue),
        '${e.metadata['item'] ?? l.actItemFallback}',
      ),
    'quotation.created' => l.actQuotationCreated(e.toValue ?? ''),
    'quotation.presented' => withMoney(l.actQuotationPresented),
    'quotation.approved' => withMoney(l.actQuotationApproved),
    'quotation.rejected' => withMoney(l.actQuotationRejected),
    'quotation.superseded' => l.actQuotationSuperseded,
    'task.created' => l.actTaskCreated(e.toValue ?? ''),
    'task.assigned' => l.actTaskAssigned,
    'task.partner_assigned' => l.actTaskPartnerAssigned,
    'task.status_changed' => l.actTaskStatusChanged(taskStatus(e.toValue)),
    'task.completed' => l.actTaskCompleted,
    'task_cost.recorded' => withMoney(l.actTaskCost),
    'payment.recorded' =>
      withMoney(l.actPaymentRecorded(method(e.metadata['method']))),
    'customer.created' => l.actCustomerCreated,
    'customer.updated' => l.actCustomerUpdated,
    _ => e.eventType,
  };
}
