import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inmore_core/inmore_core.dart';
import 'package:inmore_ui/inmore_ui.dart';

import '../data/cached.dart';

/// One tab: a big title, how fresh the numbers are, and the content —
/// all of it pull-to-refresh.
class OwnerPage extends ConsumerWidget {
  const OwnerPage({
    required this.title,
    required this.children,
    this.subtitle,
    this.cached,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Cached<Object?>? cached;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => refreshOwner(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          PageTitle(title: title, subtitle: subtitle),
          if (cached != null) Freshness(cached: cached!),
          const SizedBox(height: Space.md),
          ...children,
        ],
      ),
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.headlineSmall),
                if (subtitle != null)
                  Text(subtitle!,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      )),
              ],
            ),
          ),
          const AccountButton(),
        ],
      ),
    );
  }
}

/// "Updated 2 min ago", or — when the last refresh failed — how old the
/// numbers on screen are, so the owner never mistakes yesterday for now.
class Freshness extends StatelessWidget {
  const Freshness({required this.cached, super.key});

  final Cached<Object?> cached;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final stale = cached.refreshError != null;
    final colour =
        stale ? context.tokens.warning : context.colors.onSurfaceVariant;
    final when = l.stamp(cached.updatedAt);

    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Row(
        children: [
          Icon(
            stale
                ? Icons.cloud_off_rounded
                : Icons.check_circle_outline_rounded,
            size: 14,
            color: colour,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              stale
                  ? l.savedDataFrom(when)
                  : l.updatedAgo(l.ago(cached.updatedAt)),
              style: context.text.labelMedium?.copyWith(color: colour),
            ),
          ),
        ],
      ),
    );
  }
}

/// The signed-in person's initials; opens settings and sign-out.
class AccountButton extends ConsumerWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentEmployeeProvider).valueOrNull;
    return IconButton(
      tooltip: context.l10n.settings,
      onPressed: () => showAccountSheet(context),
      icon: me == null
          ? const Icon(Icons.account_circle_outlined)
          : InitialsAvatar(me.fullName, size: 34),
    );
  }
}

Future<void> showAccountSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AccountSheet(),
    );

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(currentEmployeeProvider).valueOrNull;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (me != null)
              Row(
                children: [
                  InitialsAvatar(me.fullName, size: 48),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UserText(me.fullName, style: context.text.titleMedium),
                        Text(me.role.tr(l), style: context.text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: Space.xl),
            const SettingsPanel(),
            const SizedBox(height: Space.xl),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ref.read(sessionRepositoryProvider).signOut();
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(l.signOut),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder page for a tab's first load.
class OwnerPageSkeleton extends StatelessWidget {
  const OwnerPageSkeleton({this.figures = true, super.key});

  final bool figures;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 200, height: 26),
              SizedBox(height: 10),
              SkeletonBox(width: 120, height: 14),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        if (figures) ...[
          const SkeletonFigures(),
          const SizedBox(height: Space.md),
          const SkeletonFigures(),
        ],
        const SkeletonList(
            rows: 4, padding: EdgeInsets.symmetric(vertical: 16)),
      ],
    );
  }
}
