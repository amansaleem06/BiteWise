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

    const width = 92.0;
    const height = 118.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final pin = Path()
      ..moveTo(width / 2, height - 8)
      ..quadraticBezierTo(12, height * 0.55, 12, 46)
      ..arcToPoint(
        const Offset(width - 12, 46),
        radius: const Radius.circular(34),
        clockwise: true,
      )
      ..quadraticBezierTo(width - 12, height * 0.55, width / 2, height - 8)
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
        ..strokeWidth = 3,
    );

    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(width / 2, 36),
        width: 64,
        height: 28,
      ),
      const Radius.circular(14),
    );
    canvas.drawRRect(pill, Paint()..color = AppColors.accent);

    final paragraphStyle = ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: 14,
      fontWeight: FontWeight.w800,
    );
    final builder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(ui.TextStyle(color: AppColors.onAccent, fontSize: 14))
      ..addText(label);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 64));
    canvas.drawParagraph(paragraph, const Offset((width - 64) / 2, 24));

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
