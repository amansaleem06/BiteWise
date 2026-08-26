import 'dart:io';
import 'dart:math' as math;
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
import '../../../restaurants/presentation/providers/page_identity_provider.dart';
import '../../../restaurants/presentation/providers/restaurant_providers.dart';
import '../providers/story_providers.dart';

class StoryEditArgs {
  const StoryEditArgs(this.image);

  final XFile image;
}

class _StoryLook {
  const _StoryLook(this.label, this.filter);
  final String label;
  final ColorFilter filter;
}

const _looks = <_StoryLook>[
  _StoryLook('Original', ColorFilter.mode(Colors.transparent, BlendMode.dst)),
  _StoryLook(
    'Warm',
    ColorFilter.mode(Color(0x55E8A050), BlendMode.overlay),
  ),
  _StoryLook(
    'Cool',
    ColorFilter.mode(Color(0x553080C0), BlendMode.overlay),
  ),
  _StoryLook(
    'Vivid',
    ColorFilter.mode(Color(0x40FF5A4A), BlendMode.softLight),
  ),
  _StoryLook(
    'Mono',
    ColorFilter.matrix(<double>[
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0, 0, 0, 1, 0,
    ]),
  ),
];

/// Crop / zoom / filter a story photo before it goes live for 24 hours.
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
  var _look = 0;
  var _rotation = 0;
  var _brightness = 0.0;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  ColorFilter get _brightnessFilter {
    final b = _brightness * 80;
    return ColorFilter.matrix(<double>[
      1, 0, 0, 0, b,
      0, 1, 0, 0, b,
      0, 0, 1, 0, b,
      0, 0, 0, 1, 0,
    ]);
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final cropped = await _captureCrop();
      final asPage = ref.read(pageIdentityProvider).actingAsPage;
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
    if (boundary == null) return widget.args.image;
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
    final identity = ref.watch(pageIdentityProvider);
    final page = identity.ownedRestaurantId != null
        ? ref
            .watch(restaurantControllerProvider(identity.ownedRestaurantId!))
            .valueOrNull
        : null;

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
                    onPressed: () {
                      _transform.value = Matrix4.identity();
                      setState(() {
                        _rotation = 0;
                        _look = 0;
                        _brightness = 0;
                      });
                    },
                    child: Text(
                      'Reset',
                      style: GoogleFonts.sourceSans3(color: AppColors.cream),
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
                            child: ColorFiltered(
                              colorFilter: _brightnessFilter,
                              child: ColorFiltered(
                                colorFilter: _looks[_look].filter,
                                child: InteractiveViewer(
                                  transformationController: _transform,
                                  minScale: 0.35,
                                  maxScale: 5,
                                  panEnabled: true,
                                  scaleEnabled: true,
                                  child: Transform.rotate(
                                    angle: _rotation * math.pi / 2,
                                    child: Image.file(
                                      File(widget.args.image.path),
                                      fit: BoxFit.contain,
                                      width: constraints.maxWidth,
                                      height: constraints.maxHeight,
                                    ),
                                  ),
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Pinch to zoom in or out · drag to reposition',
                style: GoogleFonts.sourceSans3(
                  color: AppColors.cream.withValues(alpha: 0.72),
                  fontSize: 13,
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (var i = 0; i < _looks.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_looks[i].label),
                        selected: _look == i,
                        onSelected: (_) => setState(() => _look = i),
                        selectedColor: AppColors.accent,
                        labelStyle: GoogleFonts.sourceSans3(
                          color: _look == i ? AppColors.primary : AppColors.cream,
                          fontWeight: FontWeight.w700,
                        ),
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ActionChip(
                    label: const Text('Rotate'),
                    avatar: const Icon(Icons.rotate_90_degrees_cw_outlined, size: 16),
                    onPressed: () =>
                        setState(() => _rotation = (_rotation + 1) % 4),
                  ),
                ],
              ),
            ),
            Slider(
              value: _brightness,
              min: -1,
              max: 1,
              onChanged: (v) => setState(() => _brightness = v),
              activeColor: AppColors.accent,
              label: 'Brightness',
            ),
            if (identity.hasPage)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  identity.actingAsPage
                      ? 'Sharing as ${page?.name ?? 'the restaurant page'}'
                      : 'Sharing as your personal story',
                  style: GoogleFonts.sourceSans3(
                    color: AppColors.cream.withValues(alpha: 0.8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
