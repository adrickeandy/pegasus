import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/chat_message.dart';

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

/// Thin wrapper around the Gemini generateContent REST endpoint, with
/// automatic key rotation on rate limits and short-term conversation
/// memory.
class GeminiService {
  final http.Client _client;

  /// Index of the key currently being tried first. Persists across calls
  /// so we don't keep re-hitting an exhausted key first.
  int _currentKeyIndex = 0;

  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  /// [history] is the prior turns (oldest first), NOT including the new
  /// [prompt] being sent now. Only the last [AppConfig.maxHistoryTurns]
  /// turns are actually sent, to keep token cost bounded.
  Future<String> sendMessage(
    String prompt, {
    List<ChatMessage> history = const [],
  }) async {
    final keys = AppConfig.apiKeys;
    if (keys.isEmpty) {
      throw GeminiException(
        'No API key configured. Run with --dart-define=GEMINI_API_KEY=... '
        'or --dart-define=GEMINI_API_KEYS=key1,key2,...',
      );
    }

    GeminiException? lastError;

    for (int attempt = 0; attempt < keys.length; attempt++) {
      final index = (_currentKeyIndex + attempt) % keys.length;
      final key = keys[index];

      try {
        final reply = await _callApi(prompt, key, history);
        _currentKeyIndex = index;
        return reply;
      } on _RateLimitException {
        lastError = GeminiException('All configured keys are rate-limited.');
        continue;
      } on GeminiException {
        rethrow;
      }
    }

    throw lastError ?? GeminiException('All keys failed.');
  }

  Future<String> _callApi(
    String prompt,
    String apiKey,
    List<ChatMessage> history,
  ) async {
    final uri = Uri.parse(
      '${AppConfig.baseUrl}/${AppConfig.model}:generateContent',
    );

    // Only keep the most recent N turns to bound token growth.
    final trimmed = history.length > AppConfig.maxHistoryTurns * 2
        ? history.sublist(history.length - AppConfig.maxHistoryTurns * 2)
        : history;

    final contents = [
      ...trimmed.map((m) => {
            'role': m.isUser ? 'user' : 'model',
            'parts': [
              {'text': m.text}
            ],
          }),
      {
        'role': 'user',
        'parts': [
          {'text': prompt}
        ],
      },
    ];

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': AppConfig.systemInstruction}
        ],
      },
      'contents': contents,
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

class _RateLimitException implements Exception {}
