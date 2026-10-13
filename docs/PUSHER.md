# Arcade coin pusher

Tracked by Cyclar FUNME-1.

## Player behavior

- Arcade mode is unlimited; the player can collect the current winnings at any time.
- The optional challenge accepts coins for 90 seconds.
- Both modes stop accepting input at settlement, retract the plate, and wait for
  gravity, tipping coins and tray animations before recording the result.
- An empty hand can recover if a pending payout arrives before settlement.
- Drag and release, tap the cabinet, or use left/right and Space to insert a token.
- Pause and rules stop simulation. Backgrounding does not consume game time.
- Restart cancellation preserves the current round.
- Front falls pay 1 / 3 / 5 credits for silver / gold / gems. Striped side gutters
  reclaim pieces without payout. New insertions always create one silver token.
- Stars are awarded at 10 / 25 / 40 credits. Existing stored scores are preserved;
  older records came from the previous, more generous economy.

## Simulation boundaries

`pusher_rules.dart` is a deterministic 90 Hz layered-cylinder approximation,
independent of Flutter. Absolute height gates horizontal collisions and determines
support. A coin needs central overlap to remain on another coin; loss of support
starts gravity, and a center beyond the shelf starts a visible tipping phase.
Motor motion is sinusoidal. Forward grip, return sliding and movement-driven
stack creep approximate friction without a general rigid-body solver. Parking
removes that drive while retaining gravity and momentum.

`pusher_painter.dart` projects the same positions and heights into a trapezoidal
cabinet with visible plate thickness, coin rims, gutters and a separate payout
tray. Input uses the inverse chute projection. Metallic insertion, contact,
tray and motor cues are synthesized by `tool/gen_sfx.py`; contact playback is
rate-limited. No new packages or platform-specific engine are required.

This is 2.5D: it does not simulate arbitrary disk rotation, rigid-body torque,
real material coefficients, or a physical cabinet's exact payout percentage.

## Verification

```sh
flutter test --no-pub test/games/pusher_rules_test.dart test/games/pusher_page_test.dart test/games/new_pages_smoke_test.dart
flutter analyze --no-pub lib/games/pusher lib/games/catalog.dart lib/core/audio/sound_service.dart test/games/pusher_rules_test.dart test/games/pusher_page_test.dart tool/pusher_benchmark.dart
dart tool/pusher_benchmark.dart 20
flutter build web --no-pub
```

The 26 focused tests cover height separation, landing, support-chain collapse,
plate transfer, front and side payouts, idle stability, value conservation,
frame-rate independence, timed/empty/manual settlement, pause, rules,
backgrounding, restart cancellation, input and phone/landscape/tablet layouts.

The seeded probe uses 30 credits and normal speed, with 20 seeds per strategy.
Fast strategies attempt three insertions per second. Early/late strategies
insert once per plate cycle at phase 0.1 / 0.6. These are behavioral samples,
not exhaustive balance proof or a controlled equal-insertion comparison.

| Strategy | Mean payout | Range | Mean insertions | Unfinished sessions |
| --- | ---: | ---: | ---: | ---: |
| Idle | 0.0 | 0–0 | 0.0 | 0 |
| Fast center | 2.2 | 2–3 | 32.2 | 0 |
| Fast sweep | 13.8 | 6–27 | 43.8 | 0 |
| Fast random | 12.2 | 3–24 | 42.1 | 0 |
| Fast edge | 0.1 | 0–1 | 30.1 | 0 |
| Early cycle | 30.8 | 24–41 | 39.0 | 0 |
| Late cycle | 31.8 | 23–38 | 38.0 | 0 |

The JavaScript Web build succeeds. Existing audioplayers dependencies report
Wasm incompatibility during the dry run; this does not validate a Wasm build.
Physical iOS/HarmonyOS device frame rate, audio and haptic acceptance remain
separate from the automated and browser checks.

Browser acceptance also checked the final JavaScript build at 390×844 and
844×390: cabinet, chute input, one-token debit, pause, and the horizontal
control row. The landscape collect button is fully visible without scrolling. Compact
results retain the star count as text and keep both actions visible, including
a three-star new record.
