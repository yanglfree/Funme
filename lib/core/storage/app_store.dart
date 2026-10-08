import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Best result of one game on this device.
@immutable
class GameRecord {
  const GameRecord({
    this.stars = 0,
    this.bestScore,
    this.plays = 0,
    this.wins = 0,
  });

  /// Best star rating ever reached (0–3).
  final int stars;

  /// Best score in the game's own unit (points, seconds, moves…).
  final int? bestScore;
  final int plays;
  final int wins;

  static GameRecord fromJson(Map<String, dynamic> json) => GameRecord(
        stars: (json['s'] as num?)?.toInt() ?? 0,
        bestScore: (json['b'] as num?)?.toInt(),
        plays: (json['p'] as num?)?.toInt() ?? 0,
        wins: (json['w'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        's': stars,
        if (bestScore != null) 'b': bestScore,
        'p': plays,
        'w': wins,
      };
}

/// Outcome of submitting a result, used by the result overlay to celebrate
/// new records.
@immutable
class SubmitOutcome {
  const SubmitOutcome({required this.newBestScore, required this.newStars});

  final bool newBestScore;
  final bool newStars;
}

/// Device-local persistence for settings, records and last-used setups.
///
/// The app is fully offline, so this is the only state that survives restarts.
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs) {
    _soundOn = _prefs.getBool(_kSound) ?? true;
    _musicOn = _prefs.getBool(_kMusic) ?? true;
    _hapticsOn = _prefs.getBool(_kHaptics) ?? true;
    _playLimitMinutes = _prefs.getInt(_kPlayLimit) ?? 0;
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(_kRecordPrefix)) continue;
      final raw = _prefs.getString(key);
      if (raw == null) continue;
      try {
        _records[key.substring(_kRecordPrefix.length)] =
            GameRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } on FormatException {
        // A corrupt record is dropped rather than blocking app start.
      }
    }
  }

  static const _kSound = 'settings.sound';
  static const _kMusic = 'settings.music';
  static const _kHaptics = 'settings.haptics';
  static const _kPlayLimit = 'settings.playLimitMinutes';
  static const _kRecordPrefix = 'record.';
  static const _kSetupPrefix = 'setup.';

  static AppStore? _instance;

  static AppStore get instance {
    final store = _instance;
    if (store == null) {
      throw StateError('AppStore.load() must complete before use.');
    }
    return store;
  }

  static Future<AppStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return _instance = AppStore._(prefs);
  }

  final SharedPreferences _prefs;
  final Map<String, GameRecord> _records = {};

  late bool _soundOn;
  late bool _musicOn;
  late bool _hapticsOn;
  late int _playLimitMinutes;

  bool get soundOn => _soundOn;
  bool get musicOn => _musicOn;
  bool get hapticsOn => _hapticsOn;

  /// 0 disables the eye-rest reminder.
  int get playLimitMinutes => _playLimitMinutes;

  set soundOn(bool value) => _setBool(_kSound, value, () => _soundOn = value);
  set musicOn(bool value) => _setBool(_kMusic, value, () => _musicOn = value);
  set hapticsOn(bool value) =>
      _setBool(_kHaptics, value, () => _hapticsOn = value);

  set playLimitMinutes(int value) {
    _playLimitMinutes = value;
    _prefs.setInt(_kPlayLimit, value);
    notifyListeners();
  }

  void _setBool(String key, bool value, VoidCallback assign) {
    assign();
    _prefs.setBool(key, value);
    notifyListeners();
  }

  GameRecord record(String gameId) => _records[gameId] ?? const GameRecord();

  int get totalStars => _records.values.fold(0, (sum, r) => sum + r.stars);

  /// Records one finished game. [score] is compared with the stored best using
  /// [lowerIsBetter] (moves / seconds) or higher-is-better (points).
  SubmitOutcome submit(
    String gameId, {
    required int stars,
    required bool win,
    int? score,
    bool lowerIsBetter = false,
  }) {
    final old = record(gameId);
    final best = old.bestScore;
    final newBest = score != null &&
        (best == null || (lowerIsBetter ? score < best : score > best));
    final updated = GameRecord(
      stars: stars > old.stars ? stars : old.stars,
      bestScore: newBest ? score : best,
      plays: old.plays + 1,
      wins: old.wins + (win ? 1 : 0),
    );
    _records[gameId] = updated;
    _prefs.setString('$_kRecordPrefix$gameId', jsonEncode(updated.toJson()));
    notifyListeners();
    return SubmitOutcome(
      newBestScore: newBest && best != null,
      newStars: stars > old.stars,
    );
  }

  Map<String, dynamic>? setup(String gameId) {
    final raw = _prefs.getString('$_kSetupPrefix$gameId');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  void saveSetup(String gameId, Map<String, dynamic> setup) {
    _prefs.setString('$_kSetupPrefix$gameId', jsonEncode(setup));
  }

  Future<void> clearRecords() async {
    final keys = _prefs
        .getKeys()
        .where(
            (k) => k.startsWith(_kRecordPrefix) || k.startsWith(_kSetupPrefix))
        .toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
    _records.clear();
    notifyListeners();
  }
}
