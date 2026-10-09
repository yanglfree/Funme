import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../storage/app_store.dart';
import 'sound_service.dart';

/// Hardware volume keys, taken over from the system on ohos so the app can
/// show its own volume panel. The native side consumes the key presses while
/// the app is in the foreground; every press adjusts the app volume.
///
/// Other platforms keep the system behaviour: the channel does not exist and
/// the app volume is only changed from within the app.
class VolumeKeys {
  VolumeKeys._();

  static final VolumeKeys instance = VolumeKeys._();

  static const _channel = MethodChannel('funme/volume_keys');

  /// One step of the volume panel (ten notches).
  static const step = 0.1;

  /// Bumped on every change so the panel can pop up even when the volume is
  /// already at an end stop.
  final ValueNotifier<int> changes = ValueNotifier(0);

  void install() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'press') {
        nudge(call.arguments == 'up' ? step : -step);
      }
      return null;
    });
    _channel.invokeMethod<bool>('enable').catchError((Object error) {
      // No native side (iOS, Android, tests): the system keys keep working.
      debugPrint('VolumeKeys: not taking over the keys: $error');
      return false;
    });
  }

  /// Moves the app volume by [delta], snapped to the panel's notches.
  void nudge(double delta) {
    final store = AppStore.instance;
    final next = ((store.volume + delta) / step).round() * step;
    store.volume = next.clamp(0.0, 1.0);
    changes.value++;
    SoundService.instance.play(Sfx.tap, volume: 0.8);
  }
}
