import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio/sound_service.dart';
import '../../core/feedback/fx.dart';
import '../../core/storage/app_store.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/candy_panel.dart';
import '../../core/widgets/game_scaffold.dart';
import '../../core/widgets/particles.dart';
import '../../core/widgets/result_overlay.dart';
import '../../core/widgets/setup_sheet.dart';
import '../../core/widgets/sky_background.dart';
import '../catalog.dart';
import 'sudoku_rules.dart';

class SudokuPage extends StatefulWidget {
  const SudokuPage({super.key});

  static Widget create(BuildContext context) => const SudokuPage();

  @override
  State<SudokuPage> createState() => _SudokuPageState();
}

class _SudokuPageState extends State<SudokuPage> {
  final _particles = ParticleController();
  final _focus = FocusNode();

  String _level = 'easy';
  List<int> _given = List.filled(81, 0);
  List<int> _solution = List.filled(81, 0);
  List<int> _grid = List.filled(81, 0);
  List<int> _notes = List.filled(81, 0); // bit d set = pencil mark d
  int? _selected;
  bool _noteMode = false;
  bool _loading = true;
  bool _done = false;
  int _hints = 0;
  int _seconds = 0;
  Timer? _timer;
  int _seed = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkSessionOrSetup());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _particles.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _saveSession() {
    if (_loading || _done) return;
    AppStore.instance.saveSession(GameCatalog.sudoku.id, {
      'level': _level,
      'given': _given,
      'solution': _solution,
      'grid': _grid,
      'notes': _notes,
      'hints': _hints,
      'seconds': _seconds,
    });
  }

  Future<void> _checkSessionOrSetup() async {
    final saved = AppStore.instance.session(GameCatalog.sudoku.id);
    if (saved != null) {
      try {
        final given = (saved['given'] as List).cast<int>();
        final solution = (saved['solution'] as List).cast<int>();
        final grid = (saved['grid'] as List).cast<int>();
        final notes = (saved['notes'] as List).cast<int>();
        final level = saved['level'] as String? ?? 'easy';
        final hints = saved['hints'] as int? ?? 0;
        final seconds = saved['seconds'] as int? ?? 0;
        if (given.length == 81 && solution.length == 81 && grid.length == 81) {
          _timer?.cancel();
          setState(() {
            _level = level;
            _given = given;
            _solution = solution;
            _grid = grid;
            _notes = notes.length == 81 ? notes : List.filled(81, 0);
            _hints = hints;
            _seconds = seconds;
            _done = false;
            _loading = false;
            _selected = null;
            _noteMode = false;
          });
          _timer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted && !_done) {
              setState(() => _seconds++);
              if (_seconds % 5 == 0) _saveSession();
            }
          });
          _focus.requestFocus();
          return;
        }
      } catch (_) {}
    }
    await _openSetup();
  }

  Future<void> _openSetup() async {
    final raw = AppStore.instance.setup(GameCatalog.sudoku.id) ?? const {};
    final values = await showSetupSheet(
      context,
      title: '数独',
      initial: {for (final e in raw.entries) e.key: '${e.value}'},
      groups: const [
        SetupGroup(key: 'level', title: '难度', choices: [
          SetupChoice('easy', '简单', candy: Candy.mint),
          SetupChoice('normal', '普通', candy: Candy.sun),
          SetupChoice('hard', '挑战', candy: Candy.cherry),
        ]),
      ],
    );
    if (!mounted) return;
    final v = values ?? {for (final e in raw.entries) e.key: '${e.value}'};
    if (values != null) {
      AppStore.instance.saveSetup(GameCatalog.sudoku.id, values);
    }
    AppStore.instance.clearSession(GameCatalog.sudoku.id);
    final level = v['level'];
    _level = Sudoku.clueCounts.containsKey(level) ? level! : 'easy';
    await _newGame();
  }

  Future<void> _newGame() async {
    _timer?.cancel();
    setState(() => _loading = true);
    final seed = _seed++;
    final out =
        await compute(Sudoku.generateEntry, (seed, Sudoku.clueCounts[_level]!));
    if (!mounted) return;
    setState(() {
      _given = out.sublist(0, 81);
      _solution = out.sublist(81);
      _grid = List.of(_given);
      _notes = List.filled(81, 0);
      _selected = null;
      _noteMode = false;
      _hints = 0;
      _seconds = 0;
      _done = false;
      _loading = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_done) setState(() => _seconds++);
    });
    _focus.requestFocus();
  }

  bool _fixed(int i) => _given[i] != 0;

  void _select(int i) {
    if (_done || _loading) return;
    Fx.play(Sfx.tap, volume: 0.4);
    setState(() => _selected = i);
  }

  void _enter(int digit) {
    final i = _selected;
    if (i == null || _fixed(i) || _done) return;
    if (_noteMode) {
      if (_grid[i] != 0) return;
      Fx.play(Sfx.tap, volume: 0.4);
      setState(() => _notes[i] ^= 1 << digit);
      return;
    }
    setState(() {
      _grid[i] = _grid[i] == digit ? 0 : digit;
      _notes[i] = 0;
      if (_grid[i] != 0) _clearNotesAround(i, digit);
    });
    if (_grid[i] == 0) {
      _saveSession();
      return;
    }
    if (Sudoku.conflicts(_grid).contains(i)) {
      Fx.play(Sfx.error, buzz: Buzz.light);
    } else {
      Fx.play(Sfx.place, buzz: Buzz.tap);
      _checkDone();
    }
    _saveSession();
  }

  void _clearNotesAround(int i, int digit) {
    for (var j = 0; j < 81; j++) {
      if (Sudoku.sees(i, j)) _notes[j] &= ~(1 << digit);
    }
  }

  void _erase() {
    final i = _selected;
    if (i == null || _fixed(i) || _done) return;
    Fx.tap();
    setState(() {
      _grid[i] = 0;
      _notes[i] = 0;
    });
    _saveSession();
  }

  void _hint() {
    if (_done) return;
    var i = _selected;
    if (i == null || _fixed(i) || _grid[i] == _solution[i]) {
      final wrong = [
        for (var k = 0; k < 81; k++)
          if (_grid[k] != _solution[k]) k
      ];
      if (wrong.isEmpty) return;
      i = wrong.first;
    }
    Fx.play(Sfx.star, buzz: Buzz.light);
    setState(() {
      _selected = i;
      _grid[i!] = _solution[i];
      _notes[i] = 0;
      _clearNotesAround(i, _solution[i]);
      _hints++;
    });
    _saveSession();
    _checkDone();
  }

  void _checkDone() {
    if (!Sudoku.isSolved(_grid)) return;
    _done = true;
    _timer?.cancel();
    AppStore.instance.clearSession(GameCatalog.sudoku.id);
    _finish();
  }

  Future<void> _finish() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final stars = Sudoku.starsFor(level: _level, hints: _hints);
    AppStore.instance.submit(GameCatalog.sudoku.id, stars: stars, win: true);
    final action = await showResultOverlay(
      context,
      kind: ResultKind.win,
      title: '解开啦！',
      message: _hints == 0 ? '一个提示都没用，太厉害了！' : '用了 $_hints 次提示，下次试试不用提示吧',
      stars: stars,
      stats: [
        ('用时', _clock(_seconds)),
        ('难度', _levelLabel(_level)),
        ('提示', '$_hints'),
      ],
    );
    if (!mounted) return;
    if (action == ResultAction.home) {
      Navigator.of(context).maybePop();
    } else {
      _newGame();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final label = k.keyLabel;
    if (label.length == 1 && '123456789'.contains(label)) {
      _enter(int.parse(label));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.backspace || k == LogicalKeyboardKey.delete) {
      _erase();
      return KeyEventResult.handled;
    }
    final s = _selected;
    if (s != null) {
      final next = {
        LogicalKeyboardKey.arrowUp: s - 9,
        LogicalKeyboardKey.arrowDown: s + 9,
        LogicalKeyboardKey.arrowLeft: s % 9 == 0 ? -1 : s - 1,
        LogicalKeyboardKey.arrowRight: s % 9 == 8 ? -1 : s + 1,
      }[k];
      if (next != null && next >= 0 && next < 81) {
        setState(() => _selected = next);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = List.filled(10, 9);
    for (final v in _grid) {
      if (v != 0) remaining[v]--;
    }
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: GameScaffold(
        title: '数独',
        scenery: Scenery.grape,
        rules: GameCatalog.sudoku.rules,
        onRestart: _openSetup,
        particles: _particles,
        isGameActive: () => !_loading && !_done,
        header: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            CandyChip(
                label: _levelLabel(_level), candy: Candy.grape, fontSize: 16),
            CandyChip(label: _clock(_seconds), candy: Candy.sun, fontSize: 16),
            CandyChip(label: '提示 $_hints', candy: Candy.cream, fontSize: 16),
          ],
        ),
        body: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(builder: (context, c) {
                    final side = c.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) {
                        final col = (d.localPosition.dx / side * 9).floor();
                        final row = (d.localPosition.dy / side * 9).floor();
                        if (col < 0 || col > 8 || row < 0 || row > 8) return;
                        _select(row * 9 + col);
                      },
                      child: CustomPaint(
                        size: Size.square(side),
                        painter: _SudokuPainter(
                          given: _given,
                          grid: _grid,
                          notes: _notes,
                          selected: _selected,
                          conflicts: Sudoku.conflicts(_grid),
                        ),
                      ),
                    );
                  }),
          ),
        ),
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CandyIconButton(
                  icon: Icons.edit_rounded,
                  candy: _noteMode ? Candy.sun : Candy.cream,
                  onTap: () => setState(() => _noteMode = !_noteMode),
                ),
                const SizedBox(width: 12),
                CandyIconButton(
                    icon: Icons.backspace_rounded,
                    candy: Candy.berry,
                    onTap: _erase),
                const SizedBox(width: 12),
                CandyIconButton(
                    icon: Icons.lightbulb_rounded,
                    candy: Candy.mint,
                    onTap: _hint),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var d = 1; d <= 9; d++)
                  CandyButton(
                    label: '$d',
                    width: 44,
                    height: 46,
                    lip: 4,
                    radius: 14,
                    fontSize: 22,
                    candy: _noteMode ? Candy.sun : Candy.grape,
                    foreground: _noteMode ? Palette.ink : Colors.white,
                    onTap: remaining[d] <= 0 ? null : () => _enter(d),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _clock(int s) =>
    '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

String _levelLabel(String l) => switch (l) {
      'easy' => '简单',
      'normal' => '普通',
      _ => '挑战',
    };

class _SudokuPainter extends CustomPainter {
  _SudokuPainter({
    required this.given,
    required this.grid,
    required this.notes,
    required this.selected,
    required this.conflicts,
  });

  final List<int> given;
  final List<int> grid;
  final List<int> notes;
  final int? selected;
  final Set<int> conflicts;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cell = s / 9;
    final board =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.03));
    canvas.drawRRect(board, Paint()..color = Palette.cream);
    canvas.save();
    canvas.clipRRect(board);

    final sel = selected;
    final selVal = sel == null ? 0 : grid[sel];
    for (var i = 0; i < 81; i++) {
      final rect = Rect.fromLTWH((i % 9) * cell, (i ~/ 9) * cell, cell, cell);
      Color? fill;
      if (sel != null) {
        if (i == sel) {
          fill = Candy.sun.face;
        } else if (selVal != 0 && grid[i] == selVal) {
          fill = Candy.sun.light;
        } else if (Sudoku.sees(sel, i)) {
          fill = Candy.ocean.light.withOpacity(0.45);
        }
      }
      if (conflicts.contains(i)) {
        fill = Candy.cherry.light;
      }
      if (fill != null) canvas.drawRect(rect, Paint()..color = fill);
    }

    final thin = Paint()
      ..color = Palette.inkSoft.withOpacity(0.45)
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = Palette.ink
      ..strokeWidth = 3;
    for (var k = 1; k < 9; k++) {
      final p = k * cell;
      final paint = k % 3 == 0 ? thick : thin;
      canvas.drawLine(Offset(p, 0), Offset(p, s), paint);
      canvas.drawLine(Offset(0, p), Offset(s, p), paint);
    }

    for (var i = 0; i < 81; i++) {
      final origin = Offset((i % 9) * cell, (i ~/ 9) * cell);
      final v = grid[i];
      if (v != 0) {
        final color = given[i] != 0
            ? Palette.ink
            : (conflicts.contains(i) ? Candy.cherry.shade : Candy.grape.shade);
        _text(canvas, '$v', origin + Offset(cell / 2, cell / 2), cell * 0.62,
            color, given[i] != 0 ? FontWeight.w900 : FontWeight.w700);
      } else if (notes[i] != 0) {
        for (var d = 1; d <= 9; d++) {
          if ((notes[i] & (1 << d)) == 0) continue;
          final c = origin +
              Offset(((d - 1) % 3 + 0.5) * cell / 3,
                  ((d - 1) ~/ 3 + 0.5) * cell / 3);
          _text(canvas, '$d', c, cell * 0.24, Palette.inkSoft, FontWeight.w700);
        }
      }
    }
    canvas.restore();
    canvas.drawRRect(
        board,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Palette.ink);
  }

  void _text(Canvas canvas, String text, Offset center, double size,
      Color color, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_SudokuPainter old) => true;
}
