import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../widgets/nearby_map_tab.dart';
import '../widgets/plate_roulette_sheet.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)..addListener(_tabChanged);
  }

  void _tabChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _tabs.removeListener(_tabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapActive = _tabs.index == 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: InkWell(
              onTap: () => context.push(Routes.search),
              child: const InputDecorator(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
                child: Text('Search restaurants, people, #tags…'),
              ),
            ),
          ),
          TabBar(
            controller: _tabs,
            tabs: const [Tab(text: 'Map'), Tab(text: 'Wagon Wheel')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                NearbyMapTab(isActive: mapActive),
                if (mapActive)
                  const SizedBox.shrink()
                else
                  const SingleChildScrollView(
                    padding: EdgeInsets.only(top: AppSpacing.md),
                    child: PlateRouletteSheet(embedded: true),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
