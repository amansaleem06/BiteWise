import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/cuisines.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../../../feed/presentation/widgets/feed_list.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';

/// Plate course — editorial feed with mode pill + cuisine chips.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _followingVisited = false;
  var _tab = FeedTab.forYou;
  String? _cuisineFilter;
  var _chromeVisible = true;

  bool _onScroll(ScrollNotification n) {
    if (n is UserScrollNotification) {
      if (n.direction == ScrollDirection.reverse && _chromeVisible) {
        setState(() => _chromeVisible = false);
      } else if (n.direction == ScrollDirection.forward && !_chromeVisible) {
        setState(() => _chromeVisible = true);
      }
    }
    return false;
  }

  Future<void> _pickFeedMode() async {
    final chosen = await showModalBottomSheet<FeedTab>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Plate course',
                  style: GoogleFonts.fraunces(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _ModeTile(
                  title: 'For You',
                  subtitle: 'Discover plates for your tastes',
                  selected: _tab == FeedTab.forYou,
                  onTap: () => Navigator.pop(context, FeedTab.forYou),
                ),
                const SizedBox(height: AppSpacing.xs),
                _ModeTile(
                  title: 'Following',
                  subtitle: 'Only people you follow',
                  selected: _tab == FeedTab.following,
                  onTap: () => Navigator.pop(context, FeedTab.following),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (chosen != null) {
      setState(() {
        _tab = chosen;
        if (chosen == FeedTab.following) _followingVisited = true;
      });
    }
  }

  void _openCuisinePicker() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _cuisineFilter == null,
                  onSelected: (_) {
                    setState(() => _cuisineFilter = null);
                    Navigator.pop(context);
                  },
                ),
                for (final cuisine in Cuisines.all)
                  ChoiceChip(
                    label: Text(cuisine),
                    selected: _cuisineFilter == cuisine,
                    onSelected: (_) {
                      setState(() => _cuisineFilter = cuisine);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread =
        ref.watch(hasUnreadNotificationsProvider).valueOrNull ?? false;
    final preview = Cuisines.all.take(3).toList();
    final modeLabel = _tab == FeedTab.forYou ? 'For You' : 'Following';

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.stageBackground(theme.brightness),
        ),
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                title: Row(
                  children: [
                    Text(
                      'Plate',
                      style: GoogleFonts.fraunces(
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        letterSpacing: -1,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: _pickFeedMode,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: AppColors.brandGradient,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    modeLabel,
                                    style: GoogleFonts.sourceSans3(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.expand_more_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: Badge(
                      isLabelVisible: hasUnread,
                      backgroundColor: AppColors.primary,
                      smallSize: 8,
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    onPressed: () => context.push(Routes.notifications),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: AnimatedSize(
                  duration: AppDurations.normal,
                  alignment: Alignment.topCenter,
                  child: _chromeVisible
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _Chip(
                                  label: 'All',
                                  selected: _cuisineFilter == null,
                                  onTap: () =>
                                      setState(() => _cuisineFilter = null),
                                ),
                                for (final c in preview) ...[
                                  const SizedBox(width: 8),
                                  _Chip(
                                    label: c,
                                    selected: _cuisineFilter == c,
                                    onTap: () => setState(
                                      () => _cuisineFilter =
                                          _cuisineFilter == c ? null : c,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                _Chip(
                                  label: 'See more',
                                  selected: false,
                                  emphasized: true,
                                  onTap: _openCuisinePicker,
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
            body: _tab == FeedTab.forYou
                ? FeedList(tab: FeedTab.forYou, cuisineFilter: _cuisineFilter)
                : (_followingVisited || _tab == FeedTab.following)
                    ? FeedList(
                        tab: FeedTab.following,
                        cuisineFilter: _cuisineFilter,
                      )
                    : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: selected
            ? const Icon(Icons.check_circle, color: AppColors.primary)
            : null,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? AppColors.primary
          : theme.colorScheme.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: GoogleFonts.sourceSans3(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected
                  ? Colors.white
                  : emphasized
                      ? AppColors.primary
                      : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
