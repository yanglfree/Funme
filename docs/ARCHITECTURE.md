# Architecture

## Decision: pure Flutter, no game engine

All games are 2D, mostly turn-based, with light arcade loops (snake, whack-a-mole, flappy).
Flutter's `CustomPainter` + `AnimationController` + `Ticker` renders them at 60/120 fps with
large headroom, and keeps one codebase for iOS, Android, HarmonyOS (Flutter-OH) and Web.

Rejected alternatives:

- **Flame engine** — pure Dart so it would run on Flutter-OH, but its component/game-loop model
  adds little for board games and doubles the UI paradigms in the codebase.
- **Native per platform (Swift / Kotlin / ArkTS)** — 3× the cost for no user-visible benefit at
  this rendering load.

Plugins are limited to ones with maintained HarmonyOS forks (`audioplayers`,
`shared_preferences` from openharmony-sig). Everything else (art, AI, rules) is plain Dart.

## Layout

```text
lib/
  main.dart                 bootstrap (prefs, audio, orientation)
  app/                      MaterialApp, routes, page transitions
  core/
    theme/                  palette, text styles, ThemeData
    audio/                  Sfx cue enum + SoundService (pooled players, BGM loop)
    storage/                AppStore: settings + per-game records (SharedPreferences)
    feedback/               haptics wrapper honoring settings
    game/                   GameInfo, MatchConfig, AiLevel, shared game contracts
    art/                    procedural cartoon art (animals, mascot, game icons)
    widgets/                candy buttons, sky background, confetti, result overlay,
                            game scaffold, setup sheet, parent gate, rules sheet
  features/
    home/                   home grid, categories
    parents/                parent center, play-time guard
  games/
    catalog.dart            registry of all games
    <game>/
      <game>_rules.dart     pure rules engine (no Flutter imports) — unit tested
      <game>_ai.dart        pure AI (runs in an isolate via compute when heavy)
      <game>_controller.dart ChangeNotifier: state, input, AI turns, undo, events
      <game>_page.dart      widgets + painters
test/
  games/<game>_rules_test.dart
tool/
  gen_sfx.py                procedural sound-effect synthesis (numpy) → assets/audio
```

## Game module contract

- **Rules are pure and immutable-ish**: a `State` object with `copy()`/`apply(move)` and
  `legalMoves()`. No Flutter imports, so they are unit-testable and isolate-safe.
- **Controller** owns the current state, history (undo), whose turn it is, and schedules AI
  turns with a small delay so animations finish first. It exposes one-shot UI events
  (sound cues, captures) through callbacks instead of making widgets diff states.
- **Page** builds the shared `GameScaffold`, listens to the controller, and renders. Piece
  movement uses `AnimatedPositioned` keyed by stable piece ids; boards are `CustomPainter`s.
- Heavy AI (xiangqi, gomoku, chinese checkers, jungle, reversi) runs through
  `compute()` so the UI thread keeps animating; `compute` falls back to the main isolate on Web.

## HarmonyOS notes

- Build with the Flutter-OH SDK (`~/flutter_flutter/bin/flutter`, aliased `h-flutter`):
  `h-flutter build hap --release`. When building from `ohos/` directly use `hvigorw assembleHap`.
- Never use `Color.withValues`; use `withOpacity`. Avoid `CardThemeData`.
- A signing config for bundle `com.youdroid.funme` must be generated in DevEco Studio
  (Project Structure → Signing Configs) before installing on a device.
