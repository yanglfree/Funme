import 'dart:math' as math;
import 'dart:io';

import 'package:funme/games/pusher/pusher_rules.dart';

/// Reproducible balancing probe; run with `dart tool/pusher_benchmark.dart 20`.
void main(List<String> args) {
  final seeds = args.isEmpty ? 20 : int.parse(args.first);
  for (final strategy in [
    'idle',
    'center',
    'sweep',
    'random',
    'edge',
    'early',
    'late'
  ]) {
    final scores = <int>[];
    var lost = 0;
    var inserted = 0;
    var unfinished = 0;
    for (var seed = 0; seed < seeds; seed++) {
      final g = PusherGame(mode: PusherMode.timed, random: math.Random(seed));
      final rng = math.Random(seed + 100);
      var lastCycle = -1;
      for (var frame = 0; frame < 60 * 105 && !g.over; frame++) {
        final cycle = (g.time / (4 / g.speed)).floor();
        final phase = (g.time / (4 / g.speed)) % 1;
        final phased = strategy == 'early' || strategy == 'late';
        final ready = phased
            ? cycle != lastCycle && phase >= (strategy == 'early' ? 0.1 : 0.6)
            : frame % 20 == 0;
        if (strategy != 'idle' && ready) {
          final x = switch (strategy) {
            'sweep' => 0.6 + (frame ~/ 20 % 10) * 8.8 / 9,
            'random' => 0.6 + rng.nextDouble() * 8.8,
            'edge' => 0.6,
            _ => 5.0,
          };
          if (g.drop(x)) lastCycle = cycle;
        }
        g.advance(1 / 60);
      }
      scores.add(g.score);
      lost += g.lost;
      inserted += g.inserted;
      if (!g.over) unfinished++;
    }
    final mean = scores.reduce((a, b) => a + b) / seeds;
    stdout.writeln('$strategy: score=${mean.toStringAsFixed(1)} '
        'range=${scores.reduce(math.min)}..${scores.reduce(math.max)} '
        'inserted=${(inserted / seeds).toStringAsFixed(1)} '
        'lost=${(lost / seeds).toStringAsFixed(1)} '
        'threeStars=${scores.where((s) => PusherGame.starsFor(s) == 3).length}/$seeds '
        'unfinished=$unfinished');
  }
}
