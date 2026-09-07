import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/ai_config.dart';
import '../errors/app_exception.dart';

/// One image attached to a Gemini request.
class GeminiImage {
  const GeminiImage(this.bytes, {this.mimeType = 'image/jpeg'});

  final Uint8List bytes;
  final String mimeType;
}

/// Thin REST client for the Gemini generateContent endpoint.
///
/// Responses are forced to `application/json` so callers always parse
/// structured output instead of prose.
class GeminiService {
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool get isConfigured => AiConfig.hasGeminiKey;

  /// Sends [prompt] (plus optional [images]) and returns the decoded JSON.
  Future<Map<String, dynamic>> generateJson({
    required String model,
    required String prompt,
    List<GeminiImage> images = const [],
    int maxOutputTokens = 2048,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!isConfigured) {
      throw const AppException(
        'AI features are not configured in this build. '
        'Build with --dart-define=GEMINI_API_KEY=... to enable them.',
        code: 'GEMINI_KEY_MISSING',
      );
    }

    final body = {
      'contents': [
        {
          'parts': [
            for (final image in images)
              {
                'inline_data': {
                  'mime_type': image.mimeType,
                  'data': base64Encode(image.bytes),
                },
              },
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'maxOutputTokens': maxOutputTokens,
        'temperature': 0.4,
      },
    };

    final res = await _client
        .post(
          Uri.https(
            'generativelanguage.googleapis.com',
            '/v1beta/models/$model:generateContent',
          ),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': AiConfig.geminiApiKey,
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);

    final decoded = jsonDecode(res.body);
    if (res.statusCode != 200) {
      final error = decoded is Map<String, dynamic>
          ? decoded['error'] as Map<String, dynamic>?
          : null;
      debugPrint('Gemini error ${res.statusCode}: ${error?['message']}');
      throw AppException(
        'AI request failed. Please try again.',
        code: (error?['status'] as String?) ?? 'HTTP_${res.statusCode}',
      );
    }

    final text = _firstCandidateText(decoded);
    if (text == null || text.trim().isEmpty) {
      throw const AppException(
        'AI returned an empty response.',
        code: 'GEMINI_EMPTY',
      );
    }

    final parsed = jsonDecode(text);
    if (parsed is Map<String, dynamic>) return parsed;
    throw const AppException(
      'AI returned an unexpected format.',
      code: 'GEMINI_BAD_JSON',
    );
  }

  static String? _firstCandidateText(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return null;
    final candidates = decoded['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) return null;
    final content =
        (candidates.first as Map<String, dynamic>)['content']
            as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? const [];
    for (final part in parts) {
      final text = (part as Map<String, dynamic>)['text'] as String?;
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }
}
