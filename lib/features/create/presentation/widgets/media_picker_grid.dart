import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

/// Horizontal strip of selected photos with remove buttons and an
/// add tile (gallery / camera).
class MediaPickerGrid extends StatelessWidget {
  const MediaPickerGrid({
    super.key,
    required this.images,
    required this.onAddFromGallery,
    required this.onAddFromCamera,
    required this.onRemove,
    this.onReorder,
    this.maxImages = 10,
  });

  final List<XFile> images;
  final VoidCallback onAddFromGallery;
  final VoidCallback onAddFromCamera;
  final void Function(int index) onRemove;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final int maxImages;

  @override
  Widget build(BuildContext context) {
    const tileSize = 104.0;
    final canAdd = images.length < maxImages;
    final extra = canAdd ? 1 : 0;

    return SizedBox(
      height: tileSize,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: images.length + extra,
        proxyDecorator: (child, index, animation) => AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Transform.scale(
            scale: 1.05,
            child: child,
          ),
          child: child,
        ),
        onReorder: (oldIndex, newIndex) {
          if (oldIndex >= images.length) return;
          var dest = newIndex;
          if (dest > images.length) dest = images.length;
          onReorder?.call(oldIndex, dest);
        },
        itemBuilder: (context, index) {
          if (index == images.length) {
            return _AddTile(
              key: const ValueKey('add-photo'),
              size: tileSize,
              onGallery: onAddFromGallery,
              onCamera: onAddFromCamera,
            );
          }
          return ReorderableDelayedDragStartListener(
            key: ValueKey(images[index].path),
            index: index,
            enabled: onReorder != null && images.length > 1,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: _PhotoTile(
                size: tileSize,
                file: images[index],
                onRemove: () => onRemove(index),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.size,
    required this.file,
    required this.onRemove,
  });

  final double size;
  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Image.file(
            File(file.path),
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    super.key,
    required this.size,
    required this.onGallery,
    required this.onCamera,
  });

  final double size;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onCamera();
                },
              ),
            ],
          ),
        ),
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: theme.colorScheme.outline),
          color: AppColors.primaryLight.withValues(alpha: 0.3),
        ),
        child: const Icon(
          Icons.add_a_photo_outlined,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}
