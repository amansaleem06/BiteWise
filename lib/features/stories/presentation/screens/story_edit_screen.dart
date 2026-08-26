import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../restaurants/presentation/providers/restaurant_providers.dart';
import '../providers/story_providers.dart';

class StoryEditArgs {
  const StoryEditArgs(this.image);

  final XFile image;
}

/// Crop / zoom a story photo before it goes live for 24 hours.
class StoryEditScreen extends ConsumerStatefulWidget {
  const StoryEditScreen({super.key, required this.args});

  final StoryEditArgs args;

  @override
  ConsumerState<StoryEditScreen> createState() => _StoryEditScreenState();
}

class _StoryEditScreenState extends ConsumerState<StoryEditScreen> {
  final _cropKey = GlobalKey();
  final _transform = TransformationController();
  var _busy = false;
  var _asRestaurant = true;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final cropped = await _captureCrop();
      final owned = ref.read(currentUserProvider)?.ownedRestaurantId;
      final asPage = _asRestaurant && owned != null && owned.isNotEmpty;
      await ref.read(storyActionsProvider).publish(
            cropped,
            asRestaurant: asPage,
          );
      if (!mounted) return;
      AppSnackbar.success(context, 'Story is live for 24 hours');
      context.pop();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, userMessageFrom(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<XFile> _captureCrop() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      return widget.args.image;
    }
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return widget.args.image;

    final jpeg = await FlutterImageCompress.compressWithList(
      bytes.buffer.asUint8List(),
      quality: 85,
      format: CompressFormat.jpeg,
    );
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/story_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(jpeg, flush: true);
    return XFile(path);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final ownedId = me?.ownedRestaurantId;
    final page = ownedId != null && ownedId.isNotEmpty
        ? ref.watch(restaurantControllerProvider(ownedId)).valueOrNull
        : null;
    final pageName = page?.name ?? me?.businessName;
    final canPostAsPage = ownedId != null && ownedId.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _busy ? null : () => context.pop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.cream,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Edit story',
                      style: GoogleFonts.fraunces(
                        color: AppColors.cream,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _share,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.cream,
                            ),
                          )
                        : Text(
                            'Share',
                            style: GoogleFonts.sourceSans3(
                              color: AppColors.cream,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: const Color(0xFF1A1A1A),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return RepaintBoundary(
                            key: _cropKey,
                            child: InteractiveViewer(
                              transformationController: _transform,
                              minScale: 1,
                              maxScale: 4,
                              child: SizedBox(
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                child: Image.file(
                                  File(widget.args.image.path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Pinch to zoom, drag to crop',
                style: GoogleFonts.sourceSans3(
                  color: AppColors.cream.withValues(alpha: 0.72),
                  fontSize: 13,
                ),
              ),
            ),
            if (canPostAsPage)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: SwitchListTile.adaptive(
                  value: _asRestaurant,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _asRestaurant = v),
                  title: Text(
                    'Post as ${pageName ?? 'restaurant'}',
                    style: GoogleFonts.sourceSans3(
                      color: AppColors.cream,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Uses the restaurant name and logo, not your personal profile',
                    style: GoogleFonts.sourceSans3(
                      color: AppColors.cream.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
