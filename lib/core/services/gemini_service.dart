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
    List<String> fallbackModels = const [],
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

    final models = <String>[
      model,
      for (final fallback in fallbackModels)
        if (fallback != model) fallback,
    ];

    Object? lastError;
    for (final current in models) {
      try {
        return await _generateJsonOnce(
          model: current,
          prompt: prompt,
          images: images,
          maxOutputTokens: maxOutputTokens,
          timeout: timeout,
          disableThinking: true,
        );
      } on AppException catch (e) {
        var error = e;
        if (e.code == 'INVALID_ARGUMENT' || e.code == 'HTTP_400') {
          try {
            return await _generateJsonOnce(
              model: current,
              prompt: prompt,
              images: images,
              maxOutputTokens: maxOutputTokens,
              timeout: timeout,
              disableThinking: false,
            );
          } on AppException catch (retryError) {
            error = retryError;
          }
        }
        lastError = error;
        final retryable = error.code == 'NOT_FOUND' ||
            error.code == 'HTTP_404' ||
            error.code == 'INVALID_ARGUMENT' ||
            error.code == 'HTTP_400';
        if (!retryable || current == models.last) throw error;
        debugPrint('Gemini $current failed (${error.code}); trying next model.');
      }
    }

    Error.throwWithStackTrace(
      lastError ?? const AppException('AI request failed. Please try again.'),
      StackTrace.current,
    );
  }

  Future<Map<String, dynamic>> _generateJsonOnce({
    required String model,
    required String prompt,
    required List<GeminiImage> images,
    required int maxOutputTokens,
    required Duration timeout,
    required bool disableThinking,
  }) async {
    final key = AiConfig.geminiApiKey.trim();
    final body = <String, dynamic>{
      'contents': [
        {
          'role': 'user',
          'parts': [
            for (final image in images)
              {
                'inlineData': {
                  'mimeType': image.mimeType,
                  'data': base64Encode(image.bytes),
                },
              },
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'maxOutputTokens': maxOutputTokens,
        'temperature': 0.4,
        if (disableThinking)
          'thinkingConfig': {'thinkingBudget': 0},
      },
    };

    final res = await _client
        .post(
          Uri.https(
            'generativelanguage.googleapis.com',
            '/v1beta/models/$model:generateContent',
            {'key': key},
          ),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': key,
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);

    final decoded = _tryDecode(res.body);
    if (res.statusCode != 200) {
      final error = decoded is Map<String, dynamic>
          ? decoded['error'] as Map<String, dynamic>?
          : null;
      final apiMessage = error?['message'] as String?;
      final apiStatus = error?['status'] as String?;
      debugPrint(
        'Gemini error ${res.statusCode} $model: $apiStatus $apiMessage',
      );
      throw AppException(
        _userMessage(res.statusCode, apiStatus, apiMessage),
        code: apiStatus ?? 'HTTP_${res.statusCode}',
      );
    }

    final text = _firstCandidateText(decoded);
    if (text == null || text.trim().isEmpty) {
      throw const AppException(
        'AI returned an empty response.',
        code: 'GEMINI_EMPTY',
      );
    }

    final parsed = _tryDecode(_stripFences(text));
    if (parsed is Map<String, dynamic>) return parsed;
    throw const AppException(
      'AI returned an unexpected format.',
      code: 'GEMINI_BAD_JSON',
    );
  }

  static String _userMessage(
    int status,
    String? apiStatus,
    String? apiMessage,
  ) {
    final detail = (apiMessage ?? '').toLowerCase();
    if (status == 401 ||
        status == 403 ||
        apiStatus == 'PERMISSION_DENIED' ||
        apiStatus == 'UNAUTHENTICATED' ||
        detail.contains('api key')) {
      return 'Gemini rejected this API key. In Google AI Studio, create a '
          'new key with no app restriction, allow the Generative Language '
          'API, and put it in GEMINI_API_KEY — do not reuse the Places key.';
    }
    if (status == 404 || apiStatus == 'NOT_FOUND') {
      return 'Gemini model is unavailable. Please try again.';
    }
    if (status == 429 || apiStatus == 'RESOURCE_EXHAUSTED') {
      return 'Gemini is busy. Please wait a moment and try again.';
    }
    return 'AI request failed. Please try again.';
  }

  static dynamic _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return raw;
    }
  }

  static String _stripFences(String text) {
    final trimmed = text.trim();
    final match = RegExp(
      r'^```(?:json)?\s*([\s\S]*?)\s*```$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    return match?[1]?.trim() ?? trimmed;
  }

  static String? _firstCandidateText(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return null;
    final candidates = decoded['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) return null;
    final first = candidates.first;
    if (first is! Map<String, dynamic>) return null;
    final content = first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? const [];
    for (final part in parts) {
      if (part is! Map<String, dynamic>) continue;
      final text = part['text'] as String?;
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }
}
