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

class _RateLimitException implements Exception {}

/// Wrapper around the Gemini API with:
/// - streaming responses (streamGenerateContent)
/// - automatic key rotation on rate limits
/// - bounded conversation memory
/// - optional single file attachment per message
class GeminiService {
  final http.Client _client;
  int _currentKeyIndex = 0;

  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  /// Streams reply text chunks as they arrive. [history] is prior turns
  /// (oldest first), NOT including the new [prompt]. Only the last
  /// [AppConfig.maxHistoryTurns] turns are sent, to bound token growth.
  Stream<String> sendMessageStream(
    String prompt, {
    List<ChatMessage> history = const [],
    Attachment? attachment,
  }) async* {
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
        var succeeded = false;
        await for (final chunk
            in _streamApi(prompt, key, history, attachment)) {
          succeeded = true;
          yield chunk;
        }
        if (succeeded) {
          _currentKeyIndex = index;
          return;
        }
      } on _RateLimitException {
        lastError = GeminiException('All configured keys are rate-limited.');
        continue;
      } on GeminiException {
        rethrow;
      }
    }

    throw lastError ?? GeminiException('All keys failed.');
  }

  Stream<String> _streamApi(
    String prompt,
    String apiKey,
    List<ChatMessage> history,
    Attachment? attachment,
  ) async* {
    final uri = Uri.parse(
      '${AppConfig.baseUrl}/${AppConfig.model}:streamGenerateContent?alt=sse',
    );

    final trimmed = history.length > AppConfig.maxHistoryTurns * 2
        ? history.sublist(history.length - AppConfig.maxHistoryTurns * 2)
        : history;

    final userParts = <Map<String, dynamic>>[
      {'text': prompt},
    ];
    if (attachment != null) {
      userParts.add({
        'inline_data': {
          'mime_type': attachment.mimeType,
          'data': attachment.base64Data,
        },
      });
    }

    final contents = [
      ...trimmed.map((m) => {
            'role': m.isUser ? 'user' : 'model',
            'parts': [
              {'text': m.text}
            ],
          }),
      {'role': 'user', 'parts': userParts},
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
        'thinkingConfig': {'thinkingBudget': AppConfig.thinkingBudget},
      },
    });

    final request = http.Request('POST', uri)
      ..headers['x-goog-api-key'] = apiKey
      ..headers['content-type'] = 'application/json'
      ..body = body;

    http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(
            const Duration(seconds: 45),
          );
    } catch (e) {
      throw GeminiException('Network error — check your connection.');
    }

    if (response.statusCode == 429) {
      throw _RateLimitException();
    }

    if (response.statusCode != 200) {
      final raw = await response.stream.bytesToString();
      throw GeminiException(
        'API error (${response.statusCode}): ${_extractErrorMessage(raw)}',
      );
    }

    // Server-Sent Events: each event is a line starting with "data: "
    // followed by a JSON chunk. We buffer partial lines across network
    // packets since SSE frames don't always align with TCP chunk edges.
    String buffer = '';
    await for (final bytes in response.stream) {
      buffer += utf8.decode(bytes, allowMalformed: true);
      final lines = buffer.split('\n');
      buffer = lines.removeLast(); // keep any incomplete trailing line

      for (final line in lines) {
        final trimmedLine = line.trim();
        if (!trimmedLine.startsWith('data: ')) continue;
        final jsonStr = trimmedLine.substring(6).trim();
        if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

        try {
          final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
          final candidates = decoded['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) continue;
          final parts = candidates[0]['content']?['parts'] as List?;
          if (parts == null) continue;
          final text =
              parts.map((p) => p['text'] as String? ?? '').join();
          if (text.isNotEmpty) yield text;
        } catch (_) {
          // Skip malformed/partial chunks rather than crashing the stream.
          continue;
        }
      }
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
