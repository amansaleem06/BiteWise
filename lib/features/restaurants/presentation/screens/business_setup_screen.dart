import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../../core/services/places_search_service.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../create/presentation/providers/create_post_providers.dart';
import '../providers/restaurant_providers.dart';
import '../widgets/claim_pending_card.dart';

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
  PlaceSuggestion? _selectedPlace;
  XFile? _proofImage;
  String? _claimCode;

  @override
  void initState() {
    super.initState();
    final me = ref.read(currentUserProvider);
    _name.text = me?.businessName ?? '';
    _address.text = me?.businessAddress ?? '';
    _phone.text = me?.businessPhone ?? '';
    _email.text = me?.businessEmail ?? me?.email ?? '';
    if ((me?.pendingClaimCode ?? '').isNotEmpty &&
        (me?.pendingClaimRestaurantId ?? '').isNotEmpty) {
      _step = 3;
      _claimCode = me!.pendingClaimCode;
    } else if (!(me?.needsBusinessDetails ?? true)) {
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

  Future<void> _pickListing(PlaceSuggestion place) async {
    if (_selectingPlaceId != null) return;
    setState(() => _selectingPlaceId = place.placeId);
    try {
      final details = (place.phone == null || place.phone!.isEmpty)
          ? await PlacesSearchService().fetchPlaceDetails(place.placeId)
          : place;
      if (!mounted) return;
      setState(() {
        _selectedPlace = details;
        _selectingPlaceId = null;
        _step = 2;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedPlace = place;
        _selectingPlaceId = null;
        _step = 2;
      });
      AppSnackbar.error(context, userMessageFrom(e));
    }
  }

  Future<void> _submitClaim() async {
    final place = _selectedPlace;
    final proof = _proofImage;
    final me = ref.read(currentUserProvider);
    if (place == null || proof == null || me == null) return;
    setState(() => _saving = true);
    try {
      final proofUrl = await MediaUploadService().uploadRestaurantImage(
        uid: me.uid,
        file: proof,
        kind: 'claim-proof',
      );
      final result = await ref
          .read(restaurantRepositoryProvider)
          .claimFromPlace(place, proofUrl: proofUrl);
      ref.invalidate(authStateProvider);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _claimCode = result.claimCode;
        _step = 3;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
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
          switch (_step) {
            0 => 'Verify your business',
            2 => 'Prove you own it',
            3 => 'Claim submitted',
            _ => 'Claim your restaurant',
          },
          style: GoogleFonts.fraunces(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            switch (_step) {
              0 =>
                'These details must match the public Google listing. They are a check, not the verified badge — anyone can look up a name and phone on Maps.',
              2 =>
                'A random user can find this restaurant on Maps. Upload a photo only the owner would have: the storefront sign, or a business license.',
              3 =>
                'The listing stays unclaimed until TasteWise support confirms your proof. You cannot post as the restaurant yet.',
              _ =>
                'Pick the Google Maps listing that matches the name, address, and phone you entered.',
            },
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
                    label: 'Phone as shown on Google Maps',
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
          ] else if (_step == 1) ...[
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
                            ? () => _pickListing(place)
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
          ] else if (_step == 2 && _selectedPlace != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.place_outlined, color: AppColors.primary),
              ),
              title: Text(_selectedPlace!.name),
              subtitle: Text(
                [
                  if ((_selectedPlace!.address ?? '').isNotEmpty)
                    _selectedPlace!.address!,
                  if ((_selectedPlace!.phone ?? '').isNotEmpty)
                    _selectedPlace!.phone!,
                ].join('\n'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () async {
                final image = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (image == null || !mounted) return;
                setState(() => _proofImage = image);
              },
              icon: const Icon(Icons.photo_outlined),
              label: Text(
                _proofImage == null
                    ? 'Upload storefront or license photo'
                    : 'Photo selected — tap to change',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Submit claim for review',
              isLoading: _saving,
              onPressed: _proofImage == null ? null : _submitClaim,
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        _step = 1;
                        _selectedPlace = null;
                        _proofImage = null;
                      }),
              child: const Text('Pick a different listing'),
            ),
          ] else if (_step == 3) ...[
            ClaimPendingCard(
              restaurantName: _selectedPlace?.name ??
                  ref.read(currentUserProvider)?.businessName ??
                  'your restaurant',
              claimCode: _claimCode ??
                  ref.read(currentUserProvider)?.pendingClaimCode ??
                  '',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Back to home',
              onPressed: () => context.go(Routes.home),
            ),
          ],
        ],
      ),
    );
  }
}
