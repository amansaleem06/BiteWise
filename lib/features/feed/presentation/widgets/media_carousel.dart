import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/post.dart';

/// Swipeable media viewer with page dots and double-tap-to-like.
///
/// Video playback ships with the video milestone; for now videos render
/// their poster frame with a play affordance.
class MediaCarousel extends StatefulWidget {
  const MediaCarousel({
    super.key,
    required this.media,
    this.onDoubleTap,
  });

  final List<PostMedia> media;
  final VoidCallback? onDoubleTap;

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  int _page = 0;
  bool _showHeart = false;

  void _handleDoubleTap() {
    widget.onDoubleTap?.call();
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) return const SizedBox.shrink();

    // Clamp aspect ratio so extreme images can't hijack the feed.
    final ratio = widget.media.first.aspectRatio.clamp(0.8, 1.91);

    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: AspectRatio(
        aspectRatio: ratio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              itemCount: widget.media.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => _MediaItem(item: widget.media[i]),
            ),
            // Like burst animation.
            Center(
              child: AnimatedScale(
                scale: _showHeart ? 1 : 0,
                duration: AppDurations.normal,
                curve: Curves.easeOutBack,
                child: Icon(
                  Icons.favorite_rounded,
                  size: 96,
                  color: Colors.white.withValues(alpha: 0.9),
                  shadows: const [
                    Shadow(color: Colors.black38, blurRadius: 24),
                  ],
                ),
              ),
            ),
            if (widget.media.length > 1) ...[
              // Page counter chip.
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${_page + 1}/${widget.media.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // Page dots.
              Positioned(
                bottom: AppSpacing.sm,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.media.length,
                    (i) => AnimatedContainer(
                      duration: AppDurations.fast,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 8 : 6,
                      height: i == _page ? 8 : 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MediaItem extends StatelessWidget {
  const _MediaItem({required this.item});

  final PostMedia item;

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        item.type == MediaType.video ? (item.thumbnailUrl ?? '') : item.url;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            fadeInDuration: AppDurations.normal,
            placeholder: (_, __) =>
                Container(color: AppColors.primaryLight.withValues(alpha: 0.4)),
            errorWidget: (_, __, ___) => Container(
              color: AppColors.primaryLight.withValues(alpha: 0.4),
              child: const Icon(
                Icons.broken_image_outlined,
                color: AppColors.primaryDark,
              ),
            ),
          )
        else
          Container(color: AppColors.charcoalLight),
        if (item.type == MediaType.video)
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
      ],
    );
  }
}
