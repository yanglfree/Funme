import '../audio/sound_service.dart';
import 'haptics.dart';

enum Buzz { none, tap, light, medium, heavy }

/// One-liner for "sound + haptic" feedback, the pairing used by every
/// interaction in the app.
abstract final class Fx {
  static void play(Sfx cue, {Buzz buzz = Buzz.none, double volume = 1.0}) {
    SoundService.instance.play(cue, volume: volume);
    switch (buzz) {
      case Buzz.none:
        break;
      case Buzz.tap:
        Haptics.tap();
      case Buzz.light:
        Haptics.light();
      case Buzz.medium:
        Haptics.medium();
      case Buzz.heavy:
        Haptics.heavy();
    }
  }

  static void tap() => play(Sfx.tap, buzz: Buzz.tap);
  static void error() => play(Sfx.error, buzz: Buzz.light);
}
