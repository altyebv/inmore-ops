import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

/// Ctrl+K: jump to any request by number, customer or title.
///
/// Supervisors get asked about jobs by phone all day — "where's the café
/// order?" — and this answers that in two keystrokes from any screen,
/// closed requests included.
Future<void> showCommandPalette(BuildContext context) => showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => const _CommandPalette(),
    );

final _paletteResultsProvider = FutureProvider.autoDispose
    .family<List<RequestSummary>, String>((ref, query) async {
  if (query.trim().isEmpty) return const [];
  return ref
      .watch(requestRepositoryProvider)
      .board(openOnly: false, search: query.trim(), limit: 8);
});

class _CommandPalette extends ConsumerStatefulWidget {
  const _CommandPalette();

  @override
  ConsumerState<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<_CommandPalette> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int _selected = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (mounted) {
        setState(() {
          _query = v;
          _selected = 0;
        });
      }
    });
  }

  void _open(RequestSummary r) {
    Navigator.pop(context);
    context.go('/requests/${r.id}');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final results = ref.watch(_paletteResultsProvider(_query));
    final list = results.valueOrNull ?? const <RequestSummary>[];

    return Align(
      alignment: const Alignment(0, -0.55),
      child: Material(
        color: context.colors.surfaceContainerLowest,
        elevation: 12,
        shadowColor: Colors.black45,
        borderRadius: BorderRadius.circular(Radii.xl),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Focus(
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                      list.isNotEmpty) {
                    setState(() => _selected = (_selected + 1) % list.length);
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                      list.isNotEmpty) {
                    setState(() => _selected =
                        (_selected - 1 + list.length) % list.length);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onChanged,
                  onSubmitted: (_) {
                    if (list.isNotEmpty) {
                      _open(list[_selected.clamp(0, list.length - 1)]);
                    }
                  },
                  style: context.text.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w400),
                  decoration: InputDecoration(
                    hintText: l.commandHint,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    prefixIcon: const Icon(Icons.search_rounded),
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
              ),
              const Divider(),
              if (results.isLoading) const CmykProgressBar(height: 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: _query.trim().isEmpty
                    ? _Hint(text: l.commandStart)
                    : results.hasError
                        ? ErrorState(error: results.error!, compact: true)
                        : list.isEmpty && !results.isLoading
                            ? _Hint(text: l.commandEmpty)
                            : ListView.builder(
                                shrinkWrap: true,
                                padding: const EdgeInsets.all(Space.sm),
                                itemCount: list.length,
                                itemBuilder: (context, i) => _Result(
                                  request: list[i],
                                  selected: i == _selected,
                                  onTap: () => _open(list[i]),
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Text(text,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            )),
      );
}

class _Result extends StatelessWidget {
  const _Result({
    required this.request,
    required this.selected,
    required this.onTap,
  });

  final RequestSummary request;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListTile(
      selected: selected,
      onTap: onTap,
      leading: Text(
        request.reference,
        style: context.text.titleSmall?.copyWith(
          color: context.colors.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      title: UserText(request.customerName,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: request.title == null
          ? null
          : UserText(request.title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall),
      trailing: StatusBadge(
        request.status.tr(l),
        color: context.tokens.stage(request.status),
        dot: true,
      ),
    );
  }
}
