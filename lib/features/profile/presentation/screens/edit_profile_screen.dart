import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/error_text.dart';
import 'avatar_crop_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _bio;
  final _dietary = <DietaryPreference>{};

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _name = TextEditingController(text: user?.displayName ?? '');
    _bio = TextEditingController(text: user?.bio ?? '');
    _dietary.addAll(user?.dietaryPreferences ?? const []);
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(editProfileControllerProvider.notifier).save(
          displayName: _name.text,
          bio: _bio.text,
          dietaryPreferences: _dietary.toList(),
        );
    if (!mounted) return;
    if (ok) {
      AppSnackbar.success(context, 'Profile updated');
      context.pop();
    } else {
      AppSnackbar.error(context, 'Couldn\'t save. Try again.');
    }
  }

  Future<void> _changeAvatar() async {
    XFile? cropped;
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (image == null || !mounted) return;
      if (await image.length() > 20 * 1024 * 1024) {
        throw const FormatException(
            'Please choose a photo smaller than 20 MB.');
      }
      if (!mounted) return;
      cropped = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(
          builder: (_) => AvatarCropScreen(image: image),
        ),
      );
      if (cropped == null || !mounted) return;
      final ok = await ref
          .read(editProfileControllerProvider.notifier)
          .uploadAvatar(cropped);
      if (!mounted) return;
      if (ok) {
        AppSnackbar.success(context, 'Photo updated');
      } else {
        final error = ref.read(editProfileControllerProvider).error;
        AppSnackbar.error(
          context,
          error == null ? 'Photo upload failed. Please retry.' : userMessageFrom(error),
        );
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, userMessageFrom(e));
    } finally {
      if (cropped != null) {
        try {
          await File(cropped.path).delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _removeAvatar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove profile photo?'),
        content: const Text(
          'Your default profile avatar will be shown instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove photo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await ref
        .read(editProfileControllerProvider.notifier)
        .removeAvatar();
    if (!mounted) return;
    if (ok) {
      AppSnackbar.success(context, 'Profile photo removed');
    } else {
      final error = ref.read(editProfileControllerProvider).error;
      AppSnackbar.error(
        context,
        error == null ? 'Could not remove photo. Please retry.' : userMessageFrom(error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final saving = ref.watch(editProfileControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage: user.photoUrl != null
                            ? CachedNetworkImageProvider(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null
                            ? Text(
                                user.displayName.isNotEmpty
                                    ? user.displayName[0].toUpperCase()
                                    : '?',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge
                                    ?.copyWith(color: AppColors.primaryDark),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: saving ? null : _changeAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: saving ? null : _changeAvatar,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        user.photoUrl == null ? 'Add photo' : 'Change photo',
                      ),
                    ),
                    if (user.photoUrl != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      TextButton.icon(
                        onPressed: saving ? null : _removeAvatar,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Remove photo'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AppTextField(
                        label: 'Name',
                        controller: _name,
                        validator: Validators.displayName,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _bio,
                        maxLines: 3,
                        maxLength: 160,
                        validator: (value) => (value?.trim().length ?? 0) > 160
                            ? 'Bio must be 160 characters or fewer'
                            : null,
                        decoration: const InputDecoration(labelText: 'Bio'),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Dietary preferences',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'TasteWise boosts matching plates and restaurants in your feed.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final preference in DietaryPreference.values)
                      FilterChip(
                        label: Text(preference.label),
                        tooltip: preference.description,
                        selected: _dietary.contains(preference),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _dietary.add(preference);
                          } else {
                            _dietary.remove(preference);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Save',
                  isLoading: saving,
                  onPressed: _save,
                ),
              ],
            ),
    );
  }
}
