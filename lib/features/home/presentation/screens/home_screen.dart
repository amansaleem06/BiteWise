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

/// Home: TasteWise wordmark + single feed mode control + cuisine chips.
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
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.16),
                      theme.scaffoldBackgroundColor.withValues(alpha: 0.88),
                      AppColors.secondary.withValues(alpha: 0.06),
                    ],
                  ),
                ),
              ),
              title: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    AppColors.primaryDark,
                    AppColors.charcoal,
                    Color(0xFFC33530),
                  ],
                ).createShader(bounds),
                child: Text(
                  AppStrings.appName,
                  style: GoogleFonts.fraunces(
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                    height: 1,
                    letterSpacing: -1.1,
                    color: Colors.white,
                  ),
                ),
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
                        child: Column(
                          children: [
                            _FeedModeSwitch(
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

/// One combined control: sliding highlight shows the active mode only.
class _FeedModeSwitch extends StatelessWidget {
  const _FeedModeSwitch({required this.value, required this.onChanged});

  final FeedTab value;
  final ValueChanged<FeedTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final isForYou = value == FeedTab.forYou;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final thumbW = (width - 6) / 2;

        return Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: AppDurations.normal,
                curve: Curves.easeOutCubic,
                left: isForYou ? 3 : 3 + thumbW,
                top: 3,
                bottom: 3,
                width: thumbW,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.95),
                        AppColors.primaryDark.withValues(alpha: 0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _ModeHitTarget(
                      label: 'For You',
                      selected: isForYou,
                      onTap: () => onChanged(FeedTab.forYou),
                    ),
                  ),
                  Expanded(
                    child: _ModeHitTarget(
                      label: 'Following',
                      selected: !isForYou,
                      onTap: () => onChanged(FeedTab.following),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeHitTarget extends StatelessWidget {
  const _ModeHitTarget({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: AppDurations.fast,
          style: GoogleFonts.sourceSans3(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.2,
            color: selected ? Colors.white : AppColors.textSecondaryLight,
          ),
          child: Text(label),
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
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.secondary.withValues(alpha: 0.05);
    final fg = selected
        ? Colors.white
        : emphasized
            ? AppColors.primaryDark
            : AppColors.textSecondaryLight;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
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
