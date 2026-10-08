import 'package:flutter/services.dart';

import '../storage/app_store.dart';

/// Haptic feedback that honors the parent-center toggle.
abstract final class Haptics {
  static bool get _enabled {
    try {
      return AppStore.instance.hapticsOn;
    } on StateError {
      return false;
    }
  }

  static void tap() {
    if (_enabled) HapticFeedback.selectionClick();
  }

  static void light() {
    if (_enabled) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (_enabled) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (_enabled) HapticFeedback.heavyImpact();
  }
}
