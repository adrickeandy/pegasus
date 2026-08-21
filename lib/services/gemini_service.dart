import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

/// Thin wrapper around the Gemini generateContent REST endpoint, with
/// automatic key rotation on rate limits.
///
/// Deliberately stateless per message: each call sends only the current
/// prompt, not a growing history. That's what "no history yet" means at
/// the API level — it also keeps token usage flat and predictable per
/// message instead of growing every single turn.
class GeminiService {
  final http.Client _client;

  /// Index of the key currently being tried first. Persists across calls
  /// within this session so once a key is known to be cooling down, we
  /// don't waste a request re-trying it every single message.
  int _currentKeyIndex = 0;

  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> sendMessage(String prompt) async {
    final keys = AppConfig.apiKeys;
    if (keys.isEmpty) {
      throw GeminiException(
        'No API key configured. Run with --dart-define=GEMINI_API_KEY=... '
        'or --dart-define=GEMINI_API_KEYS=key1,key2,...',
      );
    }

    GeminiException? lastError;

    // Try each key at most once per message, starting from the last known
    // good index so we don't keep re-hitting an exhausted key first.
    for (int attempt = 0; attempt < keys.length; attempt++) {
      final index = (_currentKeyIndex + attempt) % keys.length;
      final key = keys[index];

      try {
        final reply = await _callApi(prompt, key);
        _currentKeyIndex = index; // remember the key that worked
        return reply;
      } on _RateLimitException {
        // This key is exhausted — move on to the next one silently.
        lastError = GeminiException('All configured keys are rate-limited.');
        continue;
      } on GeminiException {
        // Non-rate-limit error (bad key, network issue, etc.) — don't
        // burn through every remaining key for a non-quota problem.
        rethrow;
      }
    }

    throw lastError ?? GeminiException('All keys failed.');
  }

  Future<String> _callApi(String prompt, String apiKey) async {
    final uri = Uri.parse(
      '${AppConfig.baseUrl}/${AppConfig.model}:generateContent',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ],
        }
      ],
      'generationConfig': {
        'maxOutputTokens': AppConfig.maxOutputTokens,
        'thinkingConfig': {
          'thinkingBudget': AppConfig.thinkingBudget,
        },
      },
    });

    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'x-goog-api-key': apiKey,
              'content-type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw GeminiException('Network error — check your connection.');
    }

    if (response.statusCode == 429) {
      throw _RateLimitException();
    }

    if (response.statusCode != 200) {
      final msg = _extractErrorMessage(response.body);
      throw GeminiException('API error (${response.statusCode}): $msg');
    }

    return _extractReplyText(response.body);
  }

  String _extractReplyText(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw GeminiException('Empty response from model.');
      }
      final parts = candidates[0]['content']['parts'] as List;
      return parts.map((p) => p['text'] as String? ?? '').join().trim();
    } catch (e) {
      if (e is GeminiException) rethrow;
      throw GeminiException('Could not parse response.');
    }
  }

  String _extractErrorMessage(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody) as Map<String, dynamic>;
      return decoded['error']?['message'] as String? ?? 'Unknown error';
    } catch (_) {
      return 'Unknown error';
    }
  }

  void dispose() => _client.close();
}

/// Internal marker — a 429 means "try the next key", not "give up".
class _RateLimitException implements Exception {}
