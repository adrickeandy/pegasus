# Pegasus

A glassmorphic, token-efficient AI chat app in Flutter — streaming replies,
persistent conversation history with a side panel, markdown rendering,
file attachments, animated UI, and automatic key failover.

## Run it

```bash
flutter pub get
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

### Multiple keys (automatic failover on rate limits)

```bash
flutter run --dart-define=GEMINI_API_KEYS=key1,key2,key3
```

## What was fixed in this version

**The "dead app" bug:** `sqflite` (the local database package) only ships
native support for Android/iOS — not Windows or Linux desktop. Every call
to save or load a conversation was silently failing before your message
could ever reach the screen, which is why sending a message looked like
it did nothing at all. Fixed by initializing `sqflite_common_ffi` for
desktop platforms in `main.dart`.

**Silent failures in general:** the message-sending flow in
`chat_screen.dart` now has a catch-all around every step, not just the
API call — so if local storage (or anything else) fails again in the
future, you'll see a visible error bubble instead of the message just
disappearing.

## New this version: UI polish

- **Entrance animation** — each message fades and slides in
  (`widgets/animated_entrance.dart`).
- **Hover glow** — buttons, the input bar, and side-panel items light up
  with a soft accent-colored glow on hover (`widgets/hover_glow.dart`).
  This only activates on platforms with a real mouse (desktop) — touch
  devices simply skip it.
- **Focus glow** — the input bar gets a subtle glow border while typing.
- **Bubble lift on hover** — message bubbles rise slightly with a soft
  shadow when hovered.
- **Pulsing glow** — the empty-state icon breathes gently instead of
  sitting static.

## Features

- Streaming replies (`streamGenerateContent` over SSE)
- Persistent history via SQLite, with a side panel to browse/switch/delete
  past conversations
- Markdown rendering (bold, lists, code blocks)
- Copy to clipboard (long-press any bubble)
- File attachments (image/PDF/text, 4MB cap)
- "Pegasus" identity via a system instruction
- Automatic key rotation on rate limits
- Glassmorphic UI with animation throughout

## Where your tokens go

1. Extended thinking is OFF by default (`thinkingBudget: 0` in `config.dart`)
2. Memory capped at the last `maxHistoryTurns` (6 by default)
3. `maxOutputTokens` capped at 1024
4. Attachments capped at 4MB

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
  theme/app_theme.dart           # glass color palette + gradient + glow presets
  widgets/
    glass_container.dart         # reusable frosted-glass panel
    hover_glow.dart              # reusable hover glow wrapper
    animated_entrance.dart       # fade+slide entrance wrapper
    message_bubble.dart          # markdown + copy + glass + hover lift
    chat_input.dart              # text input + file picker + focus glow
    side_panel.dart              # conversation history drawer
    typing_indicator.dart
  screens/chat_screen.dart       # wires everything together
  main.dart                      # sqflite FFI init for desktop
```

## Building on Windows via GitHub Actions

`.github/workflows/build-apk.yml` is set to Windows-only for now (Android
build hit a `compileSdk` issue mid-project that wasn't worth blocking on —
see the note in `ADDING_FEATURES.html` for how to pick that back up later).

Push to `main` and check the **Actions** tab; download `pegasus-windows`
from the finished run's Artifacts section, unzip, run the `.exe` inside.

## Adding a new feature

See `ADDING_FEATURES.html` (open in any browser) for where things live and
the pattern to follow when extending this codebase.

## A note on this build

This codebase was written and reasoned through carefully, but **not
compiled or run locally** — there's no Flutter toolchain available in the
environment that generated it, only the ability to check that every
file's brackets balance correctly. Your GitHub Actions build is the real
first compile. If it fails, share the log the same way as before and it
gets fixed the same way.
