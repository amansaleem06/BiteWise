import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/ai_config.dart';
import '../errors/app_exception.dart';

/// One image attached to a Gemini request.
class GeminiImage {
  const GeminiImage(this.bytes, {this.mimeType = 'image/jpeg'});

  final Uint8List bytes;
  final String mimeType;
}

class _Endpoint {
  const _Endpoint(this.model, this.version);

  final String model;
  final String version;
}

/// Thin REST client for the Gemini generateContent endpoint.
///
/// Responses are forced to `application/json` so callers always parse
/// structured output instead of prose.
class GeminiService {
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _cacheModelKey = 'gemini.workingModel';
  static const _cacheVersionKey = 'gemini.workingVersion';

  /// Shared across Diet Plan / vision so we do not rediscover every call.
  static _Endpoint? _cached;
  static List<String>? _listedModels;

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

    await _restoreCache();
    final candidates = await _candidates(model, fallbackModels);
    AppException? last;

    for (var i = 0; i < candidates.length; i++) {
      final current = candidates[i];
      try {
        final result = await _generateJsonOnce(
          model: current,
          prompt: prompt,
          images: images,
          maxOutputTokens: maxOutputTokens,
          timeout: timeout,
        );
        await _remember(_cached ?? _Endpoint(current, 'v1beta'));
        return result;
      } on AppException catch (e) {
        last = e;
        final missing = e.code == 'NOT_FOUND' || e.code == 'HTTP_404';
        final busy = e.code == 'RESOURCE_EXHAUSTED' || e.code == 'HTTP_429';
        if (busy) {
          // Same project quota — other models will fail the same way.
          throw e;
        }
        if (!missing || i == candidates.length - 1) throw e;
        debugPrint('Gemini $current failed (${e.code}); trying next model.');
      }
    }

    throw last ??
        const AppException('AI request failed. Please try again.');
  }

  Future<List<String>> _candidates(
    String preferred,
    List<String> fallbacks,
  ) async {
    final wanted = <String>[
      if (_cached != null) _cached!.model,
      preferred,
      ...fallbacks,
    ];
    final listed = await _discoverModels();
    if (listed.isEmpty) {
      return _unique(wanted).take(2).toList();
    }
    final fromWanted = [
      for (final id in wanted)
        if (listed.contains(id)) id,
    ];
    final extras = [
      for (final id in listed)
        if (id.toLowerCase().contains('flash') && !fromWanted.contains(id)) id,
    ];
    return _unique([...fromWanted, ...extras]).take(2).toList();
  }

  static List<String> _unique(Iterable<String> ids) {
    final out = <String>[];
    for (final id in ids) {
      if (id.isNotEmpty && !out.contains(id)) out.add(id);
    }
    return out;
  }

  Future<void> _restoreCache() async {
    if (_cached != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final model = prefs.getString(_cacheModelKey);
      final version = prefs.getString(_cacheVersionKey);
      if (model != null &&
          model.isNotEmpty &&
          version != null &&
          version.isNotEmpty) {
        _cached = _Endpoint(model, version);
      }
    } catch (_) {}
  }

  Future<void> _remember(_Endpoint endpoint) async {
    _cached = endpoint;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheModelKey, endpoint.model);
      await prefs.setString(_cacheVersionKey, endpoint.version);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _generateJsonOnce({
    required String model,
    required String prompt,
    required List<GeminiImage> images,
    required int maxOutputTokens,
    required Duration timeout,
  }) async {
    final key = AiConfig.geminiApiKey.trim();
    final usesThinking =
        model.contains('2.5') || model.contains('3.') || model.contains('3-');
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
        if (usesThinking) 'thinkingConfig': {'thinkingBudget': 0},
      },
    };

    final versions = _cached?.model == model
        ? <String>[_cached!.version]
        : const ['v1beta', 'v1'];

    AppException? last;
    for (final version in versions) {
      try {
        final decoded = await _postWithRetry(
          version: version,
          model: model,
          key: key,
          body: body,
          timeout: timeout,
        );
        _cached = _Endpoint(model, version);
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
      } on AppException catch (e) {
        last = e;
        final missing = e.code == 'NOT_FOUND' || e.code == 'HTTP_404';
        if (!missing) rethrow;
      }
    }
    throw last ??
        const AppException(
          'Gemini model is unavailable. Please try again.',
          code: 'NOT_FOUND',
        );
  }

  Future<Map<String, dynamic>> _postWithRetry({
    required String version,
    required String model,
    required String key,
    required Map<String, dynamic> body,
    required Duration timeout,
  }) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final res = await _client
          .post(
            Uri.https(
              'generativelanguage.googleapis.com',
              '/$version/models/$model:generateContent',
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
      if (res.statusCode == 200) {
        if (decoded is Map<String, dynamic>) return decoded;
        throw const AppException(
          'AI returned an unexpected format.',
          code: 'GEMINI_BAD_JSON',
        );
      }

      final error = decoded is Map<String, dynamic>
          ? decoded['error'] as Map<String, dynamic>?
          : null;
      final apiMessage = error?['message'] as String?;
      final apiStatus = error?['status'] as String?;
      debugPrint(
        'Gemini error ${res.statusCode} $version/$model '
        '(attempt $attempt): $apiStatus $apiMessage',
      );

      final busy =
          res.statusCode == 429 || apiStatus == 'RESOURCE_EXHAUSTED';
      if (busy && attempt < maxAttempts) {
        final wait = _retryAfter(res, attempt);
        debugPrint('Gemini busy; waiting ${wait.inSeconds}s.');
        await Future<void>.delayed(wait);
        continue;
      }

      throw AppException(
        _userMessage(res.statusCode, apiStatus, apiMessage),
        code: apiStatus ?? 'HTTP_${res.statusCode}',
      );
    }
    throw const AppException(
      'Gemini is rate-limiting this key. Wait a minute and try again.',
      code: 'RESOURCE_EXHAUSTED',
    );
  }

  static Duration _retryAfter(http.Response res, int attempt) {
    final header = res.headers['retry-after'];
    final seconds = int.tryParse(header ?? '');
    if (seconds != null && seconds > 0 && seconds <= 30) {
      return Duration(seconds: seconds);
    }
    return Duration(seconds: 3 * attempt);
  }

  Future<List<String>> _discoverModels() async {
    if (_listedModels != null) return _listedModels!;
    final key = AiConfig.geminiApiKey.trim();
    final found = <String>[];
    for (final version in const ['v1beta', 'v1']) {
      try {
        final res = await _client
            .get(
              Uri.https(
                'generativelanguage.googleapis.com',
                '/$version/models',
                {'key': key},
              ),
              headers: {'x-goog-api-key': key},
            )
            .timeout(const Duration(seconds: 15));
        final decoded = _tryDecode(res.body);
        if (res.statusCode != 200 || decoded is! Map<String, dynamic>) {
          debugPrint('Gemini list models $version: ${res.statusCode}');
          continue;
        }
        final models = decoded['models'] as List<dynamic>? ?? const [];
        for (final raw in models) {
          if (raw is! Map) continue;
          final methods = raw['supportedGenerationMethods'] as List<dynamic>? ??
              const [];
          if (!methods.contains('generateContent')) continue;
          var name = raw['name'] as String? ?? '';
          if (name.startsWith('models/')) name = name.substring(7);
          if (name.isEmpty || found.contains(name)) continue;
          found.add(name);
        }
        if (found.isNotEmpty) break;
      } catch (e) {
        debugPrint('Gemini list models $version failed: $e');
      }
    }
    found.sort(_preferFlash);
    _listedModels = found;
    debugPrint('Gemini models available: $found');
    return found;
  }

  static int _preferFlash(String a, String b) {
    int rank(String id) {
      final lower = id.toLowerCase();
      if (lower.contains('flash-lite') || lower.contains('flashlite')) {
        return 0;
      }
      if (lower.contains('flash')) return 1;
      if (lower.contains('lite')) return 2;
      return 3;
    }

    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : a.compareTo(b);
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
      if (detail.contains('quota') ||
          detail.contains('limit') ||
          detail.contains('billing')) {
        return 'Gemini\'s free daily limit is used up. Wait a while, or '
            'enable billing on this AI Studio key.';
      }
      return 'Gemini is rate-limiting this key. Wait a minute and try again.';
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
