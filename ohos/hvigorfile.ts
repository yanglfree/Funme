import fs from 'fs';
import path from 'path'
import { appTasks } from '@ohos/hvigor-ohos-plugin';
import { flutterHvigorPlugin } from 'flutter-hvigor-plugin';

/**
 * Flutter-OH 3.41.10-ohos-1.0.1 ships an embedding whose OhosAutoFillHelper
 * references autoFillManager types (ViewData, FillRequest, requestAutoFill…)
 * that the installed HarmonyOS SDK does not declare, so ArkTS compilation
 * fails. The app has no text input, so the helper is loosened to untyped
 * calls (still guarded by try/catch at runtime). Idempotent; re-applied on
 * every build because ohpm may re-extract the embedding.
 */
const AUTOFILL_PATCHES: Array<[string, string]> = [
  ['autoFillType: autoFillManager.AutoFillType;', 'autoFillType: number;'],
  [
    'private static toSdkAutoFillType(value: number): autoFillManager.AutoFillType {\n    return value as autoFillManager.AutoFillType;',
    'private static toSdkAutoFillType(value: number): Object {\n    return value as Object;',
  ],
  ['autoFillType: OhosAutoFillHelper.toSdkAutoFillType(node.autoFillType),', 'autoFillType: node.autoFillType,'],
  ['private static toManagerViewData(viewData: OhosViewData): autoFillManager.ViewData {', 'private static toManagerViewData(viewData: OhosViewData): Object {'],
  ['return managerViewData as autoFillManager.ViewData;', 'return managerViewData as Object;'],
  ['static parseFillResult(viewData: autoFillManager.ViewData)', 'static parseFillResult(viewData: Object)'],
  ['type: OhosAutoFillHelper.toSdkAutoFillType(autoFillType),', 'type: autoFillType,'],
  ['triggerType: AUTOFILL_TRIGGER_AUTO_REQUEST as autoFillManager.AutoFillTriggerType,', 'triggerType: AUTOFILL_TRIGGER_AUTO_REQUEST as Object,'],
  ['} as autoFillManager.FillRequest;', '} as ESObject;'],
  ['const callback: autoFillManager.AutoFillCallback = {', 'const callback: ESObject = {'],
  ['onSuccess: (filledViewData: autoFillManager.ViewData): void => {', 'onSuccess: (filledViewData: Object): void => {'],
  ['onFailure: (result: autoFillManager.FillFailureResult): void => {', 'onFailure: (result: ESObject): void => {'],
  ['autoFillManager.requestAutoFill(uiContext, fillRequest, callback);', '(autoFillManager as ESObject).requestAutoFill(uiContext, fillRequest, callback);'],
  ['const saveRequest: autoFillManager.SaveRequest = {', 'const saveRequest: Object = {'],
  ['autoFillManager.requestAutoSave(uiContext, saveRequest, napiCallback);', '(autoFillManager as ESObject).requestAutoSave(uiContext, saveRequest, napiCallback);'],
];

function patchFlutterOhosAutoFill(projectRoot: string): void {
  const relative = path.join('oh_modules', '@ohos', 'flutter_ohos', 'src', 'main', 'ets', 'plugin', 'editing', 'OhosAutoFillHelper.ets');
  const candidates = [path.join(projectRoot, relative)];
  const ohpmRoot = path.join(projectRoot, 'oh_modules', '.ohpm');
  if (fs.existsSync(ohpmRoot)) {
    for (const name of fs.readdirSync(ohpmRoot)) {
      if (name.startsWith('@ohos+flutter_ohos@')) {
        candidates.push(path.join(ohpmRoot, name, relative));
      }
    }
  }
  for (const file of candidates) {
    if (!fs.existsSync(file)) {
      continue;
    }
    const source = fs.readFileSync(file, 'utf8');
    let patched = source;
    for (const [from, to] of AUTOFILL_PATCHES) {
      patched = patched.split(from).join(to);
    }
    if (patched !== source) {
      fs.writeFileSync(file, patched, 'utf8');
    }
  }
}

patchFlutterOhosAutoFill(__dirname);

export default {
    system: appTasks,  /* Built-in plugin of Hvigor. It cannot be modified. */
    plugins:[flutterHvigorPlugin(path.dirname(__dirname))]         /* Custom plugin to extend the functionality of Hvigor. */
}
