# Pegasus

A glassmorphic, token-efficient AI chat app in Flutter — streaming replies,
persistent conversation history with a side panel, markdown rendering,
file attachments, and automatic key failover.

## Run it

```bash
flutter pub get
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

Never hardcode the key in `config.dart` — always pass it via `--dart-define`.

```bash
flutter build apk --dart-define=GEMINI_API_KEY=your_key_here
```

### Multiple keys (automatic failover on rate limits)

```bash
flutter run --dart-define=GEMINI_API_KEYS=key1,key2,key3
```

## Features

- **Streaming replies** — text appears as it's generated (`streamGenerateContent`
  over SSE), not all at once.
- **Persistent history** — every conversation is saved locally via SQLite
  (`storage_service.dart`) and survives app restarts.
- **Side panel** — swipe from the left edge or tap the menu to browse past
  conversations, switch between them, or swipe one away to delete it.
- **Markdown rendering** — bold, lists, and code blocks render properly
  instead of showing raw `**asterisks**`.
- **Copy to clipboard** — long-press any message bubble to copy its text.
- **File attachments** — tap the `+` in the input bar to attach an image,
  PDF, or text file (4MB cap — see "Design notes" below).
- **"Pegasus" identity** — a system instruction (not a visible chat turn)
  tells the model to identify as Pegasus, not Gemini.
- **Key rotation** — automatic failover to the next key on a 429 rate limit.
- **Glassmorphic UI** — frosted, translucent panels over a dark gradient,
  built with `BackdropFilter` (see `widgets/glass_container.dart`).

## Where your tokens go (and how this app avoids waste)

1. **Extended thinking is OFF by default** (`thinkingBudget: 0`).
2. **No hidden system prompt beyond the identity line** — nothing else is
   silently prepended.
3. **Memory is capped** at the last `maxHistoryTurns` (6 by default, in
   `config.dart`) — raise it for more coherent long chats, at the cost of
   linear token growth per message.
4. **`maxOutputTokens` capped** at 1024.
5. **Attachments capped at 4MB** — large files both cost more tokens and
   risk hitting request size limits.

## Design notes

- **Attachment bytes are not persisted to disk.** `storage_service.dart`
  only stores a file's name and mime type for display in history — not
  its raw content. This keeps the local database small. Re-opening an old
  conversation shows that a file was attached, but you can't re-download
  it. If you need that, see the in-app guide file
  `ADDING_FEATURES.html` for how to extend this.
- **Conversations are created lazily** — starting a "new chat" doesn't
  write anything to the database until you actually send a first message,
  so the side panel never fills up with empty chats.

## Architecture

```
lib/
  config.dart                    # keys, model, token/history limits, identity
  models/
    chat_message.dart            # message + Attachment model
    conversation.dart            # conversation session model
  services/
    gemini_service.dart          # streaming REST calls, key rotation
    storage_service.dart         # SQLite persistence
  theme/app_theme.dart           # glass color palette + gradient
  widgets/
    glass_container.dart         # reusable frosted-glass panel
    message_bubble.dart          # markdown + copy + glass bubble
    chat_input.dart              # text input + file picker
    side_panel.dart              # conversation history drawer
    typing_indicator.dart
  screens/chat_screen.dart       # wires everything together
  main.dart
```

## Adding a new feature

See `ADDING_FEATURES.html` (open it in any browser) for a step-by-step
guide on how this codebase is structured and where to plug in new
functionality — written for exactly this situation: extending Pegasus
without breaking what already works.
