import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';

/// Refetch everything a screen might be showing.
///
/// For F5, for the network coming back, and for the laptop waking up — the
/// moments when realtime may have missed something. Whole families are
/// invalidated, so whichever request is open refetches and the others reload
/// lazily when next opened.
void refreshAll(WidgetRef ref) {
  ref
    ..invalidate(boardProvider)
    ..invalidate(myWorkProvider)
    ..invalidate(customerSearchProvider)
    ..invalidate(requestProvider)
    ..invalidate(requestItemsProvider)
    ..invalidate(requestFinancialsProvider)
    ..invalidate(requestTasksProvider)
    ..invalidate(requestQuotationsProvider)
    ..invalidate(requestPaymentsProvider)
    ..invalidate(requestActivityProvider)
    ..invalidate(activeEmployeesProvider)
    ..invalidate(productsProvider)
    ..invalidate(partnersProvider);
}
