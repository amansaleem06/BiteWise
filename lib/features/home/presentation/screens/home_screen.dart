import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/cuisines.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../../../feed/presentation/widgets/feed_list.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';

/// Home: TasteWise wordmark + For You / Following feeds.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  var _followingVisited = false;
  String? _cuisineFilter;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.index == 1) _followingVisited = true;
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread =
        ref.watch(hasUnreadNotificationsProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.appName,
          style: theme.textTheme.headlineMedium,
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
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: _cuisineFilter == null,
                        onSelected: (_) =>
                            setState(() => _cuisineFilter = null),
                      ),
                    ),
                    for (final cuisine in Cuisines.all)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: FilterChip(
                          label: Text(cuisine),
                          selected: _cuisineFilter == cuisine,
                          onSelected: (_) => setState(
                            () => _cuisineFilter =
                                _cuisineFilter == cuisine ? null : cuisine,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabs,
                labelStyle: theme.textTheme.titleSmall,
                indicatorSize: TabBarIndicatorSize.label,
                dividerHeight: 0.5,
                dividerColor: theme.colorScheme.outline,
                tabs: const [
                  Tab(text: 'For You'),
                  Tab(text: 'Following'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          FeedList(tab: FeedTab.forYou, cuisineFilter: _cuisineFilter),
          _followingVisited || _tabs.index == 1
              ? FeedList(
                  tab: FeedTab.following,
                  cuisineFilter: _cuisineFilter,
                )
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}
