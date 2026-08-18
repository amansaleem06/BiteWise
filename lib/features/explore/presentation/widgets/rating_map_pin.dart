import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../app/theme/app_colors.dart';

/// Custom map pin: maroon marker with the restaurant rating on top.
abstract final class RatingMapPin {
  static final _cache = <String, BitmapDescriptor>{};

  static Future<BitmapDescriptor> descriptor({
    required double? rating,
    required bool claimed,
  }) async {
    final label = rating == null ? '–' : rating.toStringAsFixed(1);
    final key = '$label-${claimed ? 'c' : 'u'}';
    final cached = _cache[key];
    if (cached != null) return cached;

    const width = 48.0;
    const height = 62.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final pin = Path()
      ..moveTo(width / 2, height - 4)
      ..quadraticBezierTo(6, height * 0.55, 6, 24)
      ..arcToPoint(
        const Offset(width - 6, 24),
        radius: const Radius.circular(18),
        clockwise: true,
      )
      ..quadraticBezierTo(width - 6, height * 0.55, width / 2, height - 4)
      ..close();

    canvas.drawPath(
      pin,
      Paint()..color = claimed ? AppColors.primary : const Color(0xFF6B5752),
    );
    canvas.drawPath(
      pin,
      Paint()
        ..color = AppColors.cream
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(width / 2, 20),
        width: 34,
        height: 16,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(pill, Paint()..color = AppColors.cream);

    final paragraphStyle = ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: 9,
      fontWeight: FontWeight.w800,
    );
    final builder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(ui.TextStyle(color: AppColors.primary, fontSize: 9))
      ..addText(label);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 34));
    canvas.drawParagraph(paragraph, const Offset((width - 34) / 2, 13));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return BitmapDescriptor.defaultMarker;
    final descriptor = BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
    );
    _cache[key] = descriptor;
    return descriptor;
  }
}
