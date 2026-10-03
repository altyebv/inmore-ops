import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/labels.dart';
import '../theme/tokens.dart';

/// Whether this device has a network at all.
///
/// This is the operating system's view — it can say "online" on a network
/// that cannot reach the server. That is fine for its two jobs: showing the
/// offline banner, and knowing when the network has *come back* so the
/// screens can refetch. Actual failures are still reported by the request
/// that failed.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool online(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);
  yield online(await c.checkConnectivity());
  yield* c.onConnectivityChanged.map(online).distinct();
});

/// Calls [onRefresh] when the network returns and when the app comes back to
/// the foreground.
///
/// Realtime keeps screens current while connected, but anything that changed
/// while the laptop slept or the phone sat in a pocket was never pushed. This
/// is the catch-up.
class ConnectionWatcher extends ConsumerStatefulWidget {
  const ConnectionWatcher({
    required this.onRefresh,
    required this.child,
    super.key,
  });

  final void Function(WidgetRef ref) onRefresh;
  final Widget child;

  @override
  ConsumerState<ConnectionWatcher> createState() => _ConnectionWatcherState();
}

class _ConnectionWatcherState extends ConsumerState<ConnectionWatcher>
    with WidgetsBindingObserver {
  DateTime _pausedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
    }
    // A quick glance away is not worth a refetch; half a minute is.
    if (state == AppLifecycleState.resumed &&
        DateTime.now().difference(_pausedAt) > const Duration(seconds: 30)) {
      widget.onRefresh(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectivityProvider, (previous, next) {
      final was = previous?.valueOrNull;
      final now = next.valueOrNull;
      if (was == false && now == true) {
        widget.onRefresh(ref);
        ScaffoldMessenger.maybeOf(context)
          ?..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_rounded,
                    size: 18, color: context.colors.onInverseSurface),
                const SizedBox(width: Space.md),
                Text(context.l10n.backOnline),
              ],
            ),
            width: MediaQuery.sizeOf(context).width > 700 ? 480 : null,
            duration: const Duration(seconds: 2),
          ));
      }
    });
    return widget.child;
  }
}

/// A slim strip across the top of the content while the device is offline.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({this.message, super.key});

  /// Overrides the default text — the phone says how old its saved data is.
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(connectivityProvider).valueOrNull == false;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: AlignmentDirectional.topCenter,
      child: !offline
          ? const SizedBox(width: double.infinity)
          : Material(
              color: context.colors.inverseSurface,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.lg,
                  vertical: Space.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        size: 16, color: context.colors.onInverseSurface),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        message ?? context.l10n.offlineBanner,
                        style: context.text.labelMedium?.copyWith(
                          color: context.colors.onInverseSurface,
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
