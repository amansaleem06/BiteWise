import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Local-only preview. Nothing is uploaded until Use photo is selected.
class AvatarCropScreen extends StatefulWidget {
  const AvatarCropScreen({super.key, required this.image});
  final XFile image;
  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  final _boundary = GlobalKey();
  bool _saving = false;
  bool _failed = false;
  bool _ready = false;
  Future<void> _usePhoto() async {
    setState(() => _saving = true);
    try {
      final boundary = _boundary.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image =
          await boundary.toImage(pixelRatio: 512 / boundary.size.width);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('Could not process image');
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/avatar-${const Uuid().v4()}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      if (mounted) {
        Navigator.pop(context, XFile(file.path));
      } else {
        await file.delete();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not process this photo. Try another image.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Adjust profile photo')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Pinch to zoom and drag to reposition. Your avatar will appear in a circle.',
              ),
              const SizedBox(height: 24),
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: [
                    RepaintBoundary(
                      key: _boundary,
                      child: ClipRect(
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: SizedBox.expand(
                            child: Image.file(
                              File(widget.image.path),
                              fit: BoxFit.cover,
                              frameBuilder: (context, child, frame, sync) {
                                if ((frame != null || sync) && !_ready) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (mounted) setState(() => _ready = true);
                                  });
                                }
                                return child;
                              },
                              errorBuilder: (context, error, stack) {
                                _failed = true;
                                return const Center(
                                  child: Text(
                                    'Unsupported image. Choose a different photo.',
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving || _failed || !_ready ? null : _usePhoto,
                child: Text(_saving ? 'Processing…' : 'Use photo'),
              ),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
}
