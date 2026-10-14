import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../domain/entities/discovery_location.dart';
import '../providers/discovery_location_provider.dart';

class DiscoveryLocationSheet extends ConsumerStatefulWidget {
  const DiscoveryLocationSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const DiscoveryLocationSheet(),
      );

  @override
  ConsumerState<DiscoveryLocationSheet> createState() =>
      _DiscoveryLocationSheetState();
}

class _DiscoveryLocationSheetState
    extends ConsumerState<DiscoveryLocationSheet> {
  final _city = TextEditingController();
  final _countryForCity = TextEditingController();
  final _country = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _city.dispose();
    _countryForCity.dispose();
    _country.dispose();
    super.dispose();
  }

  Future<void> _nearby() async {
    setState(() => _busy = true);
    try {
      final selected =
          await ref.read(discoveryLocationProvider.notifier).chooseNearby();
      if (!mounted) return;
      if (selected) {
        Navigator.pop(context);
      } else {
        AppSnackbar.error(
          context,
          'Location is unavailable. You can still choose a city, country, or Global.',
        );
      }
    } catch (error) {
      if (mounted) AppSnackbar.error(context, userMessageFrom(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cityChoice() async {
    await ref.read(discoveryLocationProvider.notifier).chooseCity(
          _city.text,
          country: _countryForCity.text,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _countryChoice() async {
    await ref
        .read(discoveryLocationProvider.notifier)
        .chooseCountry(_country.text);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _global() async {
    await ref.read(discoveryLocationProvider.notifier).chooseGlobal();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(discoveryLocationProvider).valueOrNull;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
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
              Text('Discover food in',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                leading: const Icon(Icons.near_me_outlined),
                title: const Text('Nearby'),
                subtitle: const Text(
                    'Use your current area when location is allowed'),
                selected: current?.scope == DiscoveryScope.nearby,
                onTap: _busy ? null : _nearby,
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: TextField(
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Search city',
                    hintText: 'e.g. Rome',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _countryForCity,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Country (optional)',
                  hintText: 'e.g. Italy',
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _city.text.trim().isEmpty ? null : _cityChoice,
                  child: const Text('Use this city'),
                ),
              ),
              TextField(
                controller: _country,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Search country',
                  hintText: 'e.g. Hungary',
                  prefixIcon: Icon(Icons.public_outlined),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      _country.text.trim().isEmpty ? null : _countryChoice,
                  child: const Text('Use this country'),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.public_rounded),
                title: const Text('Global'),
                subtitle: const Text('Show food from everywhere'),
                selected: current?.scope == DiscoveryScope.global,
                onTap: _global,
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xs),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
