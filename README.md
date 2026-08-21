# Pegasus

A lightweight, token-efficient Gemini chat app in Flutter.

## Run it

```bash
flutter pub get
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

Never hardcode the key in `config.dart` — always pass it via `--dart-define`
so it never lands in your source control. For a release build:

```bash
flutter build apk --dart-define=GEMINI_API_KEY=your_key_here
```

### Multiple keys (automatic failover on rate limits)

Pass a comma-separated list instead:

```bash
flutter run --dart-define=GEMINI_API_KEYS=key1,key2,key3
```

When a key returns a 429 (rate limited), Pegasus automatically retries the
same message with the next key in the list — no user-visible interruption.
It remembers the last working key and starts there next time, so it isn't
re-testing exhausted keys on every message.

Two things worth knowing before relying on this:
- **Non-quota errors don't trigger fallback.** A bad key or malformed
  request fails immediately instead of burning through the whole list —
  only a 429 counts as "try the next one."
- **Check Google's terms of service** on using multiple personal API keys
  for one project before depending on this long-term. Spreading a single
  person's usage across several free-tier keys to get around rate limits
  may not be allowed depending on how the keys were obtained (e.g. one
  per Google account you personally control vs. keys from other people).
  Worth a quick read at ai.google.dev's terms.

## Where your tokens go (and how this app avoids waste)

1. **Extended thinking is OFF by default** (`thinkingBudget: 0` in
   `config.dart`). On Gemini 3.5 Flash, "thinking" tokens are invisible in
   the UI but billed anyway — a 3-token prompt can cost 200+ thinking
   tokens if left on. Pegasus disables this for normal chat. Turn it back
   on only if you add tasks that genuinely need multi-step reasoning
   (complex code gen, math proofs).
2. **No hidden system prompt.** Nothing is silently prepended to your
   message. What you type is exactly what gets sent.
3. **Stateless by design (for now).** Each message is sent on its own —
   the app does not resend prior conversation turns. This matches your
   "no history yet" requirement and also keeps cost flat per message
   instead of growing with every turn. See "Adding history" below for the
   trade-off once you're ready.
4. **`maxOutputTokens` is capped** (1024 by default) so a runaway or
   looping response can't silently burn your quota.
5. **30-second request timeout** — a hung request doesn't sit open
   indefinitely.

## Architecture

```
lib/
  config.dart              # API key, model, token/thinking limits
  models/chat_message.dart # simple message model
  services/gemini_service.dart # stateless REST call, no SDK dependency
  theme/app_theme.dart     # dark theme, single source of truth for colors
  widgets/
    message_bubble.dart
    chat_input.dart
    typing_indicator.dart  # built with AnimationController, no extra package
  screens/chat_screen.dart
  main.dart
```

Only one real dependency: `http` (a few KB). No state management library,
no animation package, no SDK wrapper — kept intentionally thin so there's
nothing extra to audit or that could be doing something you didn't ask
for.

## Adding conversation history later

When you're ready, `GeminiService.sendMessage` will need to accept the
full message list instead of a single string, and `contents` in the
request body becomes an array of `{role, parts}` objects — one entry per
past turn. The trade-off to plan for: token cost then grows with every
message in the conversation, since the whole history is resent each
time. Options worth considering at that point: capping history to the
last N turns, or summarizing older turns instead of sending them
verbatim.

## Suggestions

- **Streaming responses**: swap `generateContent` for
  `streamGenerateContent` so replies appear token-by-token instead of
  waiting for the full response — feels much closer to the real Gemini
  app. Slightly more networking code (SSE parsing) but no extra
  dependency needed.
- **Rate limiting / debounce**: add a short cooldown after send to stop
  accidental double-sends from someone tapping twice.
- **Markdown rendering**: replies from Gemini often include `**bold**`,
  lists, or code blocks. Right now they render as plain text. The
  `flutter_markdown` package (small, well-maintained) would render these
  properly without much overhead.
- **Secure key storage for production**: `--dart-define` is fine for
  development, but for a real release you shouldn't ship the key inside
  the compiled app at all — anyone can extract it from the APK. The
  standard production pattern is to proxy requests through your own
  backend (e.g. a small Supabase Edge Function, since you're already on
  Supabase) that holds the key server-side, and have Pegasus call your
  backend instead of Google directly.
