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

/// Home: TasteWise wordmark + single feed-mode control + cuisine chips.
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

  void _setTab(FeedTab tab) {
    setState(() {
      _tab = tab;
      if (tab == FeedTab.following) _followingVisited = true;
    });
  }

  Future<void> _pickFeedMode() async {
    final chosen = await showModalBottomSheet<FeedTab>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Feed',
                  style: GoogleFonts.fraunces(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Choose one view at a time.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                _FeedModeOption(
                  title: 'For You',
                  subtitle: 'Discover tasty posts near your tastes',
                  icon: Icons.auto_awesome_rounded,
                  selected: _tab == FeedTab.forYou,
                  onTap: () => Navigator.pop(context, FeedTab.forYou),
                ),
                const SizedBox(height: AppSpacing.xs),
                _FeedModeOption(
                  title: 'Following',
                  subtitle: 'Only people you follow',
                  icon: Icons.group_rounded,
                  selected: _tab == FeedTab.following,
                  onTap: () => Navigator.pop(context, FeedTab.following),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (chosen != null) _setTab(chosen);
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
    final modeLabel = _tab == FeedTab.forYou ? 'For You' : 'Following';

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8EDEA),
              AppColors.backgroundLight,
              Color(0xFFF0EBE6),
            ],
          ),
        ),
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverAppBar(
                floating: true,
                snap: true,
                pinned: false,
                backgroundColor: Colors.transparent,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                titleSpacing: AppSpacing.md,
                title: Row(
                  children: [
                    Text(
                      AppStrings.appName,
                      style: GoogleFonts.fraunces(
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        height: 1,
                        letterSpacing: -1.2,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _FeedModeButton(
                          label: modeLabel,
                          onTap: _pickFeedMode,
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
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
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
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
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

/// Single combined control — shows the active mode; tap to switch.
class _FeedModeButton extends StatelessWidget {
  const _FeedModeButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.92),
                AppColors.primaryDark.withValues(alpha: 0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sourceSans3(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedModeOption extends StatelessWidget {
  const _FeedModeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.1)
          : AppColors.feedAccentSoft,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.sourceSans3(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.charcoal,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: AppColors.primary),
            ],
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
            ? Colors.white.withValues(alpha: 0.75)
            : Colors.white.withValues(alpha: 0.55);
    final fg = selected
        ? Colors.white
        : emphasized
            ? AppColors.primaryDark
            : AppColors.charcoal.withValues(alpha: 0.75);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.sourceSans3(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
