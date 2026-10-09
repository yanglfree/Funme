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
    _volume = (_prefs.getDouble(_kVolume) ?? 1.0).clamp(0.0, 1.0);
    _playLimitMinutes = _prefs.getInt(_kPlayLimit) ?? 0;
    _days = _decodeNested(_prefs.getString(_kPlayTime));
    _totals = _decodeFlat(_prefs.getString(_kPlayTimeTotal));
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
  static const _kVolume = 'settings.volume';
  static const _kPlayLimit = 'settings.playLimitMinutes';
  static const _kPlayTime = 'playtime.days';
  static const _kPlayTimeTotal = 'playtime.total';
  static const _keepDays = 14;
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

  /// Seconds played per local day (`yyyy-mm-dd`) per game id, last 14 days.
  late Map<String, Map<String, int>> _days;

  /// Seconds played per game id since the app was installed or cleared.
  late Map<String, int> _totals;

  late bool _soundOn;
  late bool _musicOn;
  late bool _hapticsOn;
  late double _volume;
  late int _playLimitMinutes;

  bool get soundOn => _soundOn;
  bool get musicOn => _musicOn;
  bool get hapticsOn => _hapticsOn;

  /// App volume 0–1 applied on top of the system volume to cues and music.
  double get volume => _volume;

  /// 0 disables the eye-rest reminder.
  int get playLimitMinutes => _playLimitMinutes;

  set soundOn(bool value) => _setBool(_kSound, value, () => _soundOn = value);
  set musicOn(bool value) => _setBool(_kMusic, value, () => _musicOn = value);
  set hapticsOn(bool value) =>
      _setBool(_kHaptics, value, () => _hapticsOn = value);

  set volume(double value) {
    final next = value.clamp(0.0, 1.0);
    if (next == _volume) return;
    _volume = next;
    _prefs.setDouble(_kVolume, next);
    notifyListeners();
  }

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

  static Map<String, int> _decodeFlat(String? raw) {
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt()));
    } on Object {
      return {};
    }
  }

  static Map<String, Map<String, int>> _decodeNested(String? raw) {
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map(
        (day, games) => MapEntry(
          day,
          (games as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, (v as num).toInt())),
        ),
      );
    } on Object {
      return {};
    }
  }

  static String dayKey(DateTime t) => '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  /// Adds foreground play time for [gameId] to today's bucket and the total.
  void addPlaySeconds(String gameId, int seconds, {DateTime? now}) {
    if (seconds <= 0) return;
    final at = now ?? DateTime.now();
    final today = _days.putIfAbsent(dayKey(at), () => {});
    today[gameId] = (today[gameId] ?? 0) + seconds;
    _totals[gameId] = (_totals[gameId] ?? 0) + seconds;
    final cutoff = dayKey(at.subtract(const Duration(days: _keepDays)));
    _days.removeWhere((day, _) => day.compareTo(cutoff) < 0);
    _prefs.setString(_kPlayTime, jsonEncode(_days));
    _prefs.setString(_kPlayTimeTotal, jsonEncode(_totals));
    notifyListeners();
  }

  /// Seconds played in [gameId] over the last [days] days including today;
  /// a null [gameId] sums every game.
  int playSeconds({String? gameId, int days = 1, DateTime? now}) {
    final at = now ?? DateTime.now();
    var sum = 0;
    for (var i = 0; i < days; i++) {
      final games = _days[dayKey(at.subtract(Duration(days: i)))];
      if (games == null) continue;
      sum += gameId == null
          ? games.values.fold(0, (a, b) => a + b)
          : games[gameId] ?? 0;
    }
    return sum;
  }

  int totalPlaySeconds([String? gameId]) => gameId == null
      ? _totals.values.fold(0, (a, b) => a + b)
      : _totals[gameId] ?? 0;

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
    _days = {};
    _totals = {};
    await _prefs.remove(_kPlayTime);
    await _prefs.remove(_kPlayTimeTotal);
    notifyListeners();
  }
}
