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
    this.maxImages = 10,
  });

  final List<XFile> images;
  final VoidCallback onAddFromGallery;
  final VoidCallback onAddFromCamera;
  final void Function(int index) onRemove;
  final int maxImages;

  @override
  Widget build(BuildContext context) {
    const tileSize = 104.0;
    final canAdd = images.length < maxImages;

    return SizedBox(
      height: tileSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: images.length + (canAdd ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          if (index == images.length) {
            return _AddTile(
              size: tileSize,
              onGallery: onAddFromGallery,
              onCamera: onAddFromCamera,
            );
          }
          return _PhotoTile(
            size: tileSize,
            file: images[index],
            onRemove: () => onRemove(index),
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
