import {
  FlutterPlugin,
  FlutterPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MethodChannel, { MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { inputConsumer, KeyCode, KeyEvent } from '@kit.InputKit';
import { Log } from '@ohos/flutter_ohos';

const TAG = 'VolumeKeysPlugin';
const CHANNEL = 'funme/volume_keys';

/**
 * Consumes the hardware volume keys while the app is in the foreground so the
 * system volume panel stays hidden; Dart receives each press and draws its own
 * panel and applies the app volume.
 */
export default class VolumeKeysPlugin implements FlutterPlugin {
  private channel: MethodChannel | null = null;
  private active = false;
  private readonly onUp = (_event: KeyEvent): void => this.emit('up');
  private readonly onDown = (_event: KeyEvent): void => this.emit('down');

  getUniqueClassName(): string {
    return TAG;
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
    this.channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult) => {
        switch (call.method) {
          case 'enable':
            result.success(this.enable());
            break;
          case 'disable':
            this.disable();
            result.success(true);
            break;
          default:
            result.notImplemented();
        }
      }
    });
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.disable();
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }

  private emit(direction: string): void {
    this.channel?.invokeMethod('press', direction);
  }

  private enable(): boolean {
    if (this.active) {
      return true;
    }
    try {
      inputConsumer.on('keyPressed',
        { key: KeyCode.KEYCODE_VOLUME_UP, action: 1, isRepeat: true }, this.onUp);
      inputConsumer.on('keyPressed',
        { key: KeyCode.KEYCODE_VOLUME_DOWN, action: 1, isRepeat: true }, this.onDown);
      this.active = true;
    } catch (e) {
      Log.e(TAG, 'Could not take over the volume keys: ' + JSON.stringify(e));
      this.disable();
    }
    return this.active;
  }

  private disable(): void {
    try {
      inputConsumer.off('keyPressed', this.onUp);
      inputConsumer.off('keyPressed', this.onDown);
    } catch (e) {
      Log.e(TAG, 'Could not release the volume keys: ' + JSON.stringify(e));
    }
    this.active = false;
  }
}
