import 'package:supabase_flutter/supabase_flutter.dart';

import '../enums/enums.dart';
import '../models/task.dart';
import 'errors.dart';

class TaskRepository {
  TaskRepository(this._db);

  final SupabaseClient _db;

  /// The My Work screen: open tasks assigned to one person, soonest first.
  Future<List<TaskSummary>> myWork(String employeeId) async {
    final rows = await _db
        .from('v_task_summary')
        .select()
        .eq('assignee_id', employeeId)
        .not('status', 'in', '(DONE,CANCELLED)')
        .order('due_at', ascending: true, nullsFirst: false)
        .order('created_at', ascending: true);
    return rows.map(TaskSummary.fromJson).toList();
  }

  Future<List<TaskSummary>> forRequest(String requestId) async {
    final rows = await _db
        .from('v_task_summary')
        .select()
        .eq('request_id', requestId)
        .order('created_at', ascending: true);
    return rows.map(TaskSummary.fromJson).toList();
  }

  /// Anyone may create a task for themselves — work is handed over verbally,
  /// so requiring a supervisor to pre-create every task would just mean tasks
  /// stop being recorded. Assigning to *someone else*, or to a partner, is for
  /// supervisors and the owner, and the database enforces that.
  Future<void> create({
    required String requestId,
    required TaskType type,
    required String title,
    String? description,
    String? requestItemId,
    String? assigneeId,
    String? partnerId,
    DateTime? dueAt,
  }) async {
    assert(
      assigneeId == null || partnerId == null,
      'A task has one executor: an employee or a partner, never both.',
    );
    final rows = await _db.from('tasks').insert({
      'request_id': requestId,
      'request_item_id': requestItemId,
      'type': type.wire,
      'title': title.trim(),
      'description': description,
      'assignee_id': assigneeId,
      'partner_id': partnerId,
      'due_at': dueAt?.toUtc().toIso8601String(),
    }).select();
    requireRow(rows, 'create this task');
  }

  /// `started_at` and `completed_at` are stamped by a trigger, so the client
  /// sends only the status.
  Future<void> setStatus(String taskId, TaskStatus status) async {
    final rows = await _db
        .from('tasks')
        .update({'status': status.wire})
        .eq('id', taskId)
        .select();
    requireRow(rows, 'update this task');
  }

  Future<void> assign(String taskId,
      {String? employeeId, String? partnerId}) async {
    final rows = await _db
        .from('tasks')
        .update({'assignee_id': employeeId, 'partner_id': partnerId})
        .eq('id', taskId)
        .select();
    requireRow(rows, 'reassign this task');
  }

  Future<void> setNotes(String taskId, String notes) async {
    final rows = await _db
        .from('tasks')
        .update({'notes': notes})
        .eq('id', taskId)
        .select();
    requireRow(rows, 'update this task');
  }

  /// What an external task cost. Separate table, so the figure is invisible to
  /// designers and production.
  Future<void> recordCost(String taskId, double amount, {String? notes}) async {
    final rows = await _db
        .from('task_costs')
        .upsert({'task_id': taskId, 'amount': amount, 'notes': notes}).select();
    requireRow(rows, 'record a cost');
  }

  Future<double?> cost(String taskId) async {
    final row = await _db
        .from('task_costs')
        .select('amount')
        .eq('task_id', taskId)
        .maybeSingle();
    final v = row?['amount'];
    if (v == null) return null;
    return v is num ? v.toDouble() : double.tryParse(v.toString());
  }
}
