import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/restaurant.dart';
import '../providers/restaurant_providers.dart';

/// Owner-only editor for the public restaurant page (logo, cover, about, menu).
class EditRestaurantScreen extends ConsumerStatefulWidget {
  const EditRestaurantScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  ConsumerState<EditRestaurantScreen> createState() =>
      _EditRestaurantScreenState();
}

class _EditRestaurantScreenState extends ConsumerState<EditRestaurantScreen> {
  final _description = TextEditingController();
  final _website = TextEditingController();
  final _phone = TextEditingController();
  final _menu = TextEditingController();
  var _ready = false;
  var _saving = false;
  String? _logoUrl;
  String? _coverUrl;

  @override
  void dispose() {
    _description.dispose();
    _website.dispose();
    _phone.dispose();
    _menu.dispose();
    super.dispose();
  }

  void _hydrate() {
    if (_ready) return;
    final restaurant =
        ref.read(restaurantControllerProvider(widget.restaurantId)).valueOrNull;
    if (restaurant == null) return;
    _description.text = restaurant.description ?? '';
    _website.text = restaurant.website ?? '';
    _phone.text = restaurant.phone ?? '';
    _menu.text = restaurant.menuNotes ?? '';
    _logoUrl = restaurant.logoUrl;
    _coverUrl = restaurant.coverUrl;
    _ready = true;
  }

  Future<void> _pick(bool cover) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: cover ? 1920 : 1024,
    );
    if (file == null) return;
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    try {
      final url = await MediaUploadService().uploadRestaurantImage(
        uid: uid,
        file: file,
        kind: cover ? 'cover' : 'logo',
      );
      if (!mounted) return;
      setState(() {
        if (cover) {
          _coverUrl = url;
        } else {
          _logoUrl = url;
        }
      });
    } catch (e) {
      if (mounted) AppSnackbar.error(context, userMessageFrom(e));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(restaurantControllerProvider(widget.restaurantId).notifier)
          .updatePage(
            description: _description.text,
            website: _website.text,
            phone: _phone.text,
            menuNotes: _menu.text,
            logoUrl: _logoUrl,
            coverUrl: _coverUrl,
          );
      if (!mounted) return;
      AppSnackbar.success(context, 'Restaurant page updated');
      context.pop();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, userMessageFrom(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(restaurantControllerProvider(widget.restaurantId));
    _hydrate();
    final restaurant = async.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          restaurant?.name ?? 'Edit page',
          style: GoogleFonts.fraunces(fontWeight: FontWeight.w700),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(userMessageFrom(e))),
        data: (_) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              'This is the public restaurant identity. Your personal name and phone from setup stay private.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Cover photo', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _pick(true),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: _coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: _coverUrl!,
                          fit: BoxFit.cover,
                        )
                      : const ColoredBox(
                          color: AppColors.primaryDark,
                          child: Center(
                            child: Icon(
                              Icons.add_a_photo_outlined,
                              color: AppColors.cream,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Logo', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _pick(false),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: _logoUrl != null
                    ? CachedNetworkImageProvider(_logoUrl!)
                    : null,
                child: _logoUrl == null
                    ? const Icon(Icons.add_a_photo_outlined)
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _description,
              maxLines: 4,
              maxLength: 600,
              decoration: const InputDecoration(
                labelText: 'About the restaurant',
                hintText: 'What diners should know about this place',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _menu,
              maxLines: 5,
              maxLength: 1200,
              decoration: const InputDecoration(
                labelText: 'Menu / specials',
                hintText: 'Today’s plates, prix fixe, seasonal notes…',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _website,
              decoration: const InputDecoration(labelText: 'Website'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(
                labelText: 'Public restaurant phone',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Diner tags on your page',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'When someone tags this restaurant, the post stays on their profile and in Mentions — not as an official page post. Choose whether every tag is public, or only ones you approve.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (restaurant != null)
              SegmentedButton<GuestFeedMode>(
                segments: const [
                  ButtonSegment(
                    value: GuestFeedMode.all,
                    label: Text('Show all'),
                  ),
                  ButtonSegment(
                    value: GuestFeedMode.approved,
                    label: Text('Only approved'),
                  ),
                ],
                selected: {restaurant.guestFeedMode},
                onSelectionChanged: (value) async {
                  try {
                    await ref
                        .read(
                          restaurantControllerProvider(widget.restaurantId)
                              .notifier,
                        )
                        .setGuestFeedMode(value.first);
                  } catch (e) {
                    if (context.mounted) {
                      AppSnackbar.error(context, userMessageFrom(e));
                    }
                  }
                },
              ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Save page',
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
