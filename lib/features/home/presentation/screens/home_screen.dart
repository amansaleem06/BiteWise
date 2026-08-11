import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/cuisines.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../../../feed/presentation/widgets/feed_list.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';

/// Home: TasteWise wordmark + compact feed toggle + cuisine chips.
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

  void _openCuisinePicker() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pick a cuisine',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
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

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: false,
              title: Text(
                AppStrings.appName,
                style: GoogleFonts.fraunces(
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  letterSpacing: -0.8,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              actions: [
                IconButton(
                  icon: Badge(
                    isLabelVisible: hasUnread,
                    backgroundColor: AppColors.primary,
                    smallSize: 8,
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                  onPressed: () => context.push(Routes.notifications),
                  tooltip: 'Notifications',
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
            SliverToBoxAdapter(
              child: AnimatedSize(
                duration: AppDurations.normal,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _chromeVisible
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        child: Column(
                          children: [
                            _FeedModeToggle(
                              value: _tab,
                              onChanged: (tab) {
                                setState(() {
                                  _tab = tab;
                                  if (tab == FeedTab.following) {
                                    _followingVisited = true;
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                _CuisinePill(
                                  label: 'All',
                                  selected: _cuisineFilter == null,
                                  onTap: () =>
                                      setState(() => _cuisineFilter = null),
                                ),
                                for (final cuisine in preview) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  _CuisinePill(
                                    label: cuisine,
                                    selected: _cuisineFilter == cuisine,
                                    onTap: () => setState(
                                      () => _cuisineFilter =
                                          _cuisineFilter == cuisine
                                              ? null
                                              : cuisine,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: AppSpacing.xs),
                                _CuisinePill(
                                  label: 'See more',
                                  selected: false,
                                  emphasized: true,
                                  onTap: _openCuisinePicker,
                                ),
                              ],
                            ),
                          ],
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
    );
  }
}

class _FeedModeToggle extends StatelessWidget {
  const _FeedModeToggle({required this.value, required this.onChanged});

  final FeedTab value;
  final ValueChanged<FeedTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleSegment(
              label: 'For You',
              selected: value == FeedTab.forYou,
              onTap: () => onChanged(FeedTab.forYou),
            ),
          ),
          Expanded(
            child: _ToggleSegment(
              label: 'Following',
              selected: value == FeedTab.following,
              onTap: () => onChanged(FeedTab.following),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? Colors.white : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _CuisinePill extends StatelessWidget {
  const _CuisinePill({
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
    final bg = selected
        ? AppColors.primary
        : emphasized
            ? AppColors.primaryLight
            : Colors.white;
    final fg = selected
        ? Colors.white
        : emphasized
            ? AppColors.primaryDark
            : AppColors.textPrimaryLight;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outlineLight,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}
