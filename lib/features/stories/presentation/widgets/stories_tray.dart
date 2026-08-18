import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/story_providers.dart';
import '../screens/story_viewer_screen.dart';

class StoriesTray extends ConsumerWidget {
  const StoriesTray({super.key});

  Future<void> _addStory(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Library'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null) return;
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1440,
    );
    if (image == null) return;
    try {
      await ref.read(storyActionsProvider).publish(image);
      if (context.mounted) {
        AppSnackbar.success(context, 'Story is live for 24 hours');
      }
    } catch (e) {
      if (context.mounted) AppSnackbar.error(context, userMessageFrom(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final rings = ref.watch(storyRingsProvider).valueOrNull ?? const [];
    if (me == null) return const SizedBox.shrink();

    final mine = rings.where((r) => r.authorId == me.uid).toList();
    final others = rings.where((r) => r.authorId != me.uid).toList();
    final ordered = [...mine, ...others];

    return SizedBox(
      height: 104,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        children: [
          _RingAvatar(
            label: mine.isEmpty ? 'Your story' : 'You',
            photoUrl: me.photoUrl,
            hasStory: mine.isNotEmpty,
            isAdd: true,
            onTap: () {
              if (mine.isNotEmpty) {
                context.push(
                  Routes.stories,
                  extra: StoryViewerArgs(rings: ordered, startIndex: 0),
                );
              } else {
                _addStory(context, ref);
              }
            },
            onAdd: () => _addStory(context, ref),
          ),
          for (var i = 0; i < others.length; i++) ...[
            const SizedBox(width: 12),
            _RingAvatar(
              label: others[i].authorName,
              photoUrl: others[i].authorPhotoUrl,
              hasStory: true,
              onTap: () => context.push(
                Routes.stories,
                extra: StoryViewerArgs(
                  rings: ordered,
                  startIndex: mine.isEmpty ? i : i + 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RingAvatar extends StatelessWidget {
  const _RingAvatar({
    required this.label,
    required this.onTap,
    this.photoUrl,
    this.hasStory = false,
    this.isAdd = false,
    this.onAdd,
  });

  final String label;
  final String? photoUrl;
  final bool hasStory;
  final bool isAdd;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: isAdd ? onAdd : null,
        child: Column(
          children: [
            SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: hasStory
                          ? const LinearGradient(
                              colors: [AppColors.primary, AppColors.accent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      border: hasStory
                          ? null
                          : Border.all(color: AppColors.outlineLight, width: 1.5),
                    ),
                  ),
                  CircleAvatar(
                    radius: 29,
                    backgroundColor: AppColors.cream,
                    backgroundImage: photoUrl != null
                        ? CachedNetworkImageProvider(photoUrl!)
                        : null,
                    child: photoUrl == null
                        ? Text(
                            label.isNotEmpty ? label[0].toUpperCase() : '+',
                            style: GoogleFonts.fraunces(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                  if (isAdd)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: GestureDetector(
                        onTap: onAdd,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.cream, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 14,
                            color: AppColors.cream,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.sourceSans3(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
