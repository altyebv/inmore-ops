import 'package:flutter/material.dart';
import 'package:inmore_core/inmore_core.dart';

import '../l10n/labels.dart';
import '../theme/tokens.dart';

/// The pipeline as a row of steps, with the current one lit.
///
/// Stages before the current one are filled in their colour, so the eye reads
/// progress from start to end; the current stage gets a ring; stages still to
/// come are outlines. A completed request lights every step in green; a
/// cancelled one greys them all.
///
/// Give it [onSelect] and each step becomes a button — the supervisor moves
/// the request by clicking where it should be.
class StageStepper extends StatelessWidget {
  const StageStepper({
    required this.status,
    this.onSelect,
    this.compact = false,
    super.key,
  });

  final RequestStatus status;
  final ValueChanged<RequestStatus>? onSelect;

  /// One thin segmented bar with the current stage named underneath — for the
  /// phone, where six labels do not fit in a row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = context.colors;
    final l = context.l10n;
    final stages = RequestStatus.pipeline;
    final current = stages.indexOf(status);
    final completed = status == RequestStatus.completed;
    final cancelled = status == RequestStatus.cancelled;

    Color colourFor(int i) {
      if (cancelled) return c.outlineVariant;
      if (completed) return t.success;
      if (i <= current) return t.stage(stages[i]);
      return c.outlineVariant;
    }

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < stages.length; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 6,
                    decoration: BoxDecoration(
                      color: colourFor(i),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            status.tr(l),
            style: context.text.labelLarge?.copyWith(
              color: cancelled ? c.onSurfaceVariant : t.stage(status),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stages.length; i++)
          Expanded(
            child: _Step(
              label: stages[i].tr(l),
              colour: colourFor(i),
              state: cancelled
                  ? _StepState.future
                  : completed || i < current
                      ? _StepState.done
                      : i == current
                          ? _StepState.current
                          : _StepState.future,
              first: i == 0,
              last: i == stages.length - 1,
              onTap: onSelect == null || stages[i] == status
                  ? null
                  : () => onSelect!(stages[i]),
            ),
          ),
      ],
    );
  }
}

enum _StepState { done, current, future }

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.colour,
    required this.state,
    required this.first,
    required this.last,
    required this.onTap,
  });

  final String label;
  final Color colour;
  final _StepState state;
  final bool first;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final line = c.outlineVariant;
    const dot = 22.0;

    final marker = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: dot,
      height: dot,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: state == _StepState.future
            ? c.surfaceContainerLowest
            : (state == _StepState.current
                ? colour.withValues(alpha: 0.16)
                : colour),
        border: Border.all(
          color: state == _StepState.future ? c.outline : colour,
          width: state == _StepState.current ? 2 : 1.5,
        ),
      ),
      child: state == _StepState.done
          ? Icon(Icons.check_rounded, size: 14, color: c.surfaceContainerLowest)
          : state == _StepState.current
              ? Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: colour, shape: BoxShape.circle),
                  ),
                )
              : null,
    );

    final content = Column(
      children: [
        SizedBox(
          height: dot,
          child: Row(
            children: [
              Expanded(
                child: first
                    ? const SizedBox()
                    : Container(
                        height: 2,
                        color: state == _StepState.future ? line : colour,
                      ),
              ),
              marker,
              Expanded(
                child: last
                    ? const SizedBox()
                    : Container(
                        height: 2,
                        color: state == _StepState.done ? colour : line,
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: context.text.labelMedium?.copyWith(
              color:
                  state == _StepState.future ? c.onSurfaceVariant : c.onSurface,
              fontWeight: state == _StepState.current
                  ? FontWeight.w600
                  : FontWeight.w500,
            ),
          ),
        ),
      ],
    );

    final padded = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: content,
    );
    if (onTap == null) return padded;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: padded,
    );
  }
}
