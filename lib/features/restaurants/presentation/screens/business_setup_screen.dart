import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/services/places_search_service.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../create/presentation/providers/create_post_providers.dart';
import '../providers/restaurant_providers.dart';

/// After Business signup: collect verifiable details, then claim a Maps listing.
class BusinessSetupScreen extends ConsumerStatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  ConsumerState<BusinessSetupScreen> createState() =>
      _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  var _step = 0;
  var _saving = false;
  String _query = '';
  String? _selectingPlaceId;

  @override
  void initState() {
    super.initState();
    final me = ref.read(currentUserProvider);
    _name.text = me?.businessName ?? '';
    _address.text = me?.businessAddress ?? '';
    _phone.text = me?.businessPhone ?? '';
    _email.text = me?.businessEmail ?? me?.email ?? '';
    if (!(me?.needsBusinessDetails ?? true)) {
      _step = 1;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _saveDetails() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(restaurantRepositoryProvider).saveBusinessDetails(
            businessName: _name.text,
            address: _address.text,
            phone: _phone.text,
            businessEmail: _email.text,
          );
      ref.invalidate(authStateProvider);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _step = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.error(context, userMessageFrom(e));
    }
  }

  Future<void> _claim(PlaceSuggestion place) async {
    if (_selectingPlaceId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm this is your restaurant'),
        content: Text(
          '${place.name}\n${place.address ?? ''}\n\n'
          'This listing becomes your restaurant page immediately. '
          'Ratings already on it stay with the page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Claim this listing'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _selectingPlaceId = place.placeId);
    try {
      await ref.read(restaurantRepositoryProvider).claimFromPlace(place);
      ref.invalidate(authStateProvider);
      if (!mounted) return;
      AppSnackbar.success(
        context,
        'Restaurant page is yours. You post as ${place.name} from now on.',
      );
      context.go(Routes.home);
    } catch (e) {
      if (!mounted) return;
      setState(() => _selectingPlaceId = null);
      AppSnackbar.error(context, userMessageFrom(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = ref.watch(placesRestaurantSearchProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _step == 0 ? 'Verify your business' : 'Claim your restaurant',
          style: GoogleFonts.fraunces(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            _step == 0
                ? 'These details are only used to match your Maps listing. They are not shown as the public identity of the restaurant page.'
                : 'Pick the Google Maps listing. After you confirm, the page is yours immediately — no review queue.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_step == 0) ...[
            Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    label: 'Business name',
                    controller: _name,
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.length < 2) return 'Enter the business name';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Business address',
                    controller: _address,
                    validator: Validators.address,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Business phone',
                    controller: _phone,
                    validator: Validators.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Business email',
                    controller: _email,
                    validator: Validators.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Continue to claim',
              isLoading: _saving,
              onPressed: _saveDetails,
            ),
          ] else ...[
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search your restaurant on Maps…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.md),
            results.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
              error: (e, _) => Text(userMessageFrom(e)),
              data: (places) {
                if (_query.trim().length < 2) {
                  return Text(
                    'Type the restaurant name as it appears on Google Maps.',
                    style: theme.textTheme.bodySmall,
                  );
                }
                if (places.isEmpty) {
                  return const Text('No Maps matches. Try a shorter name.');
                }
                return Column(
                  children: [
                    for (final place in places)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(
                            Icons.place_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(place.name),
                        subtitle: Text(place.address ?? ''),
                        trailing: _selectingPlaceId == place.placeId
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: _selectingPlaceId == null
                            ? () => _claim(place)
                            : null,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: () => context.go(Routes.profile),
              child: const Text('Claim later from Profile'),
            ),
          ],
        ],
      ),
    );
  }
}
