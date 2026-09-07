import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../config/ai_config.dart';
import 'gemini_service.dart';

/// Result of checking the photos attached to a post.
class FoodCheckResult {
  const FoodCheckResult({required this.allFood, this.failedIndexes = const []});

  /// True when every checked photo shows food/drink (or the check was
  /// skipped because AI is not configured / unavailable).
  final bool allFood;

  /// 0-based indexes of photos that do not look like food.
  final List<int> failedIndexes;
}

/// Blocks non-food photos at publish time using a cheap Gemini vision call.
///
/// Fail-open by design: a missing API key or a network/AI outage never stops
/// a diner from posting — only a confident "this is not food" does.
class FoodVisionService {
  FoodVisionService({GeminiService? gemini})
      : _gemini = gemini ?? GeminiService();

  final GeminiService _gemini;

  /// Checks up to [maxImages] photos in a single request.
  Future<FoodCheckResult> checkPostImages(
    List<XFile> images, {
    int maxImages = 6,
  }) async {
    if (!_gemini.isConfigured || images.isEmpty) {
      return const FoodCheckResult(allFood: true);
    }

    final toCheck = images.take(maxImages).toList();
    try {
      final attachments = <GeminiImage>[];
      for (final file in toCheck) {
        final bytes = await FlutterImageCompress.compressWithFile(
          file.path,
          minWidth: 512,
          minHeight: 512,
          quality: 55,
          format: CompressFormat.jpeg,
        );
        if (bytes == null) return const FoodCheckResult(allFood: true);
        attachments.add(GeminiImage(bytes));
      }

      final response = await _gemini.generateJson(
        model: AiConfig.visionModel,
        prompt: '''
You are moderating photos for a food-sharing social app. For each attached
image, in order, decide whether it belongs on a food app. ACCEPT images that
clearly show: prepared food, dishes, meals, snacks, desserts, drinks or
beverages, groceries or raw ingredients, restaurant menus, or food packaging.
REJECT anything else (selfies without food, landscapes, screenshots, pets,
memes, documents, unrelated objects).

Respond with JSON only, exactly:
{"results":[{"index":0,"food":true},{"index":1,"food":false}]}
with one entry per image, index matching the attachment order.''',
        images: attachments,
        maxOutputTokens: 512,
        timeout: const Duration(seconds: 20),
      );

      final results = response['results'] as List<dynamic>? ?? const [];
      final failed = <int>[];
      for (final raw in results) {
        if (raw is! Map<String, dynamic>) continue;
        final index = (raw['index'] as num?)?.toInt();
        final isFood = raw['food'] == true;
        if (index != null && index < toCheck.length && !isFood) {
          failed.add(index);
        }
      }
      return FoodCheckResult(allFood: failed.isEmpty, failedIndexes: failed);
    } catch (e) {
      // Never block publishing on infrastructure problems.
      debugPrint('Food photo check skipped: $e');
      return const FoodCheckResult(allFood: true);
    }
  }
}
