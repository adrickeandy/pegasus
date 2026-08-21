/// App-wide configuration.
///
/// IMPORTANT: The API key is never hardcoded in source. It's injected at
/// build/run time so it never sits in your repo or version control.
///
/// Run with:
///   flutter run --dart-define=GEMINI_API_KEY=your_key_here
/// Build with:
///   flutter build apk --dart-define=GEMINI_API_KEY=your_key_here
class AppConfig {
  AppConfig._();

  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Comma-separated list of fallback keys, e.g.
  ///   --dart-define=GEMINI_API_KEYS=key1,key2,key3
  /// Used for automatic failover when one key hits its rate limit.
  /// If unset, falls back to just [geminiApiKey].
  static const String _rawKeyList = String.fromEnvironment(
    'GEMINI_API_KEYS',
    defaultValue: '',
  );

  static List<String> get apiKeys {
    if (_rawKeyList.trim().isNotEmpty) {
      return _rawKeyList
          .split(',')
          .map((k) => k.trim())
          .where((k) => k.isNotEmpty)
          .toList();
    }
    return geminiApiKey.isNotEmpty ? [geminiApiKey] : [];
  }

  static const String model = 'gemini-3.5-flash';

  static const String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Thinking budget in tokens. Set to 0 to disable extended "thinking" —
  /// this is the single biggest silent token cost on Flash models. A basic
  /// chat app rarely needs it, so it's off by default. Raise this later if
  /// you add tasks that need deeper reasoning (e.g. code generation).
  static const int thinkingBudget = 0;

  /// Caps how long a single reply can run. Keeps runaway responses (and
  /// runaway token bills) in check. Tune to taste.
  static const int maxOutputTokens = 1024;

  static bool get hasApiKey => apiKeys.isNotEmpty;
}
