import '../models/activity.dart';
import 'formatting.dart';

/// Turn an event row into a sentence.
///
/// Lives in the shared package so the desktop app and the owner's phone
/// describe the same event with the same words. Two copies would drift, and
/// then the owner and the supervisor would be reading different accounts of
/// the same job.
///
/// Reads the stored `from`/`to` rather than re-deriving anything: the log is
/// the record, and a description that disagrees with it would be worse than a
/// terse one.
String activityDescription(ActivityEntry e) {
  final money = e.metadata['amount'];
  final moneyText =
      money == null ? '' : ' ${Fmt.money(num.tryParse('$money'))}';

  return switch (e.eventType) {
    'request.created' => 'Request created',
    'request.status_changed' =>
      'Moved from ${_label(e.fromValue)} to ${_label(e.toValue)}',
    'request.waiting_set' => 'Blocked: waiting on ${_label(e.toValue)}',
    'request.waiting_cleared' => 'Unblocked',
    'request.supervisor_changed' => 'Supervisor changed',
    'request.completed' => 'Request completed',
    'request.cancelled' =>
      'Request cancelled — ${e.metadata['reason'] ?? 'no reason given'}',
    'request.reopened' => 'Reopened from ${_label(e.fromValue)}',
    'item.added' => 'Added ${e.toValue}',
    'item.removed' => 'Removed ${e.fromValue}',
    'item.decision_changed' =>
      '${e.metadata['item'] ?? 'Item'}: ${_label(e.toValue).toLowerCase()}',
    'quotation.created' => 'Quotation v${e.toValue} drafted',
    'quotation.presented' => 'Quotation told to the customer$moneyText',
    'quotation.approved' => 'Customer approved$moneyText',
    'quotation.rejected' => 'Customer rejected$moneyText',
    'quotation.superseded' => 'Quotation replaced by a new version',
    'task.created' => 'Work added: ${e.toValue}',
    'task.assigned' => 'Work assigned',
    'task.partner_assigned' => 'Sent to an external partner',
    'task.status_changed' => 'Work ${_label(e.toValue).toLowerCase()}',
    'task.completed' => 'Work finished',
    'task_cost.recorded' => 'External cost recorded$moneyText',
    'payment.recorded' =>
      'Payment received$moneyText (${_label('${e.metadata['method']}')})',
    'customer.created' => 'Customer created',
    'customer.updated' => 'Customer details updated',
    _ => e.eventType,
  };
}

/// 'BANK_TRANSFER' -> 'Bank Transfer'
String _label(String? wire) {
  if (wire == null) return '—';
  return wire
      .split('_')
      .map(
        (w) =>
            w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase(),
      )
      .join(' ');
}
