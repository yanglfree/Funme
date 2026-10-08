# Funme Design Language

Cartoon, candy-colored, tactile. Every surface looks like a soft toy you can press.
Source of truth for tokens: `lib/core/theme/palette.dart` and `lib/core/theme/fun_theme.dart`.

## Principles

1. **Chunky and tactile** — buttons and cards are "candy blocks": a face color on top of a
   darker lip (4–6 dp). Pressing moves the face down into the lip.
2. **Ink outlines** — important game objects carry a 2.5–3 dp outline in `Palette.ink`
   (deep purple, never pure black) so shapes read clearly for kids.
3. **Never color alone** — players are distinguished by color *and* shape/face/label.
4. **Motion with meaning** — springs for arrival (`easeOutBack` / `elasticOut`), quick ease-in
   for exits, idle bobbing on things that are tappable. Reduce motion when the OS asks.
5. **Kind feedback** — losing shows encouragement, never red "FAIL" screens.

## Color tokens

| Token | Face | Shade (lip) | Use |
| --- | --- | --- | --- |
| sun | `#FFC83D` | `#E3A21A` | primary actions, stars |
| orange | `#FF8C42` | `#DB6A22` | highlights |
| berry | `#FF6B9D` | `#DB4A7C` | player 2 / pink accents |
| mint | `#34D1A0` | `#1FA47C` | success, "go" |
| grape | `#9B7BFF` | `#7653E0` | puzzle category |
| ocean | `#4AA8FF` | `#2A83D8` | board category, player 1 |
| cherry | `#FF5A5F` | `#D63A40` | danger, red side |
| cream | `#FFF8EC` | `#EBD9BD` | panels and sheets |

Ink `#3A2D5C`, soft ink `#7A6E99`, sky gradient `#6CCBFF → #BFF0FF`.

## Type

System font (PingFang / HarmonyOS Sans / Roboto) with heavy weights; a bundled cartoon font
can be enabled later via `FunFonts.family`.

| Style | Size | Weight |
| --- | --- | --- |
| display | 34 | w900 |
| title | 22 | w900 |
| body | 16 | w700 |
| caption | 13 | w700 |

Large titles use a white outline (stroke) under the fill for a sticker look.

## Shape & spacing

- Radius: 12 (chips), 20 (buttons), 28 (cards), 36 (sheets).
- Spacing scale: 4, 8, 12, 16, 24, 32.
- Touch targets: ≥ 56 dp for primary controls, ≥ 44 dp for board cells where the board allows.

## Motion tokens

| Token | Duration | Curve | Use |
| --- | --- | --- | --- |
| press | 90 ms | easeOut | button face down |
| release | 260 ms | elasticOut | button spring back |
| pop | 420 ms | easeOutBack | pieces, tiles, cards entering |
| move | 260–320 ms | easeInOutCubic | piece moves |
| celebrate | 1600 ms | — | confetti burst |

## Audio & haptics

Every tap has a short sound; game events have distinct cues (place, capture, flip, win…).
Light impact haptic on tap, medium on capture, heavy on win/lose. All toggles live in the
parent center.
