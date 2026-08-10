import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../../../feed/presentation/widgets/feed_list.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';

/// Home: BiteWise wordmark + For You / Following feeds.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasUnread =
        ref.watch(hasUnreadNotificationsProvider).valueOrNull ?? false;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: TabBar(
            labelStyle: theme.textTheme.titleSmall,
            indicatorSize: TabBarIndicatorSize.label,
            dividerHeight: 0.5,
            dividerColor: theme.colorScheme.outline,
            tabs: const [
              Tab(text: 'For You'),
              Tab(text: 'Following'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            FeedList(tab: FeedTab.forYou),
            FeedList(tab: FeedTab.following),
          ],
        ),
      ),
    );
  }
}
