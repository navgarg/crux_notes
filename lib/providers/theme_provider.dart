import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themePrefsKey = 'selectedThemeMode';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier(this._prefs) : super(ThemeMode.system) {
    _loadThemeMode();
  }

  final SharedPreferences _prefs;

  Future<void> _loadThemeMode() async {
    final themeString = _prefs.getString(_themePrefsKey);
    if (themeString == ThemeMode.light.toString()) {
      state = ThemeMode.light;
    } else if (themeString == ThemeMode.dark.toString()) {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(_themePrefsKey, mode.toString());
  }

  Future<void> toggleTheme() async {
    final Brightness platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (state == ThemeMode.light || (state == ThemeMode.system && platformBrightness == Brightness.light)) {
      setThemeMode(ThemeMode.dark);
    } else { // If dark or system (and system is currently dark)
      setThemeMode(ThemeMode.light);
    }
  }
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final prefsAsyncValue = ref.watch(sharedPreferencesProvider);
  return prefsAsyncValue.when(
    data: (prefs) => ThemeNotifier(prefs),
    loading: () => ThemeNotifier(PlaceholderSharedPreferences()),
    error: (e, s) {
      print("Error loading SharedPreferences: $e");
      // Fallback to the placeholder if shared pref loading fails
      return ThemeNotifier(PlaceholderSharedPreferences());
    },
  );
});

// This class acts as a non-persistent stub for SharedPreferences
// while the real instance is loading or if it fails to load.
class PlaceholderSharedPreferences implements SharedPreferences {
  final Map<String, Object> _map = {}; // In-memory store for the placeholder

  PlaceholderSharedPreferences() {
    print("PlaceholderSharedPreferences initialized.");
  }

  @override
  Future<bool> clear() async { _map.clear(); return true; }
  @override
  Future<bool> commit() async => true; // No actual commit needed for in-memory
  @override
  bool containsKey(String key) => _map.containsKey(key);
  @override
  Object? get(String key) => _map[key];
  @override
  bool? getBool(String key) => _map[key] as bool?;
  @override
  double? getDouble(String key) => _map[key] as double?;
  @override
  int? getInt(String key) => _map[key] as int?;
  @override
  Set<String> getKeys() => _map.keys.toSet();
  @override
  String? getString(String key) => _map[key] as String?;
  @override
  List<String>? getStringList(String key) => _map[key] as List<String>?;
  @override
  Future<void> reload() async {} // No reload needed for in-memory
  @override
  Future<bool> remove(String key) async { _map.remove(key); return true; }
  @override
  Future<bool> setBool(String key, bool value) async { _map[key] = value; print("PlaceholderSharedPreferences: setBool($key, $value)"); return true; }
  @override
  Future<bool> setDouble(String key, double value) async { _map[key] = value; return true; }
  @override
  Future<bool> setInt(String key, int value) async { _map[key] = value; return true; }
  @override
  Future<bool> setString(String key, String value) async { _map[key] = value; print("PlaceholderSharedPreferences: setString($key, $value)"); return true; }
  @override
  Future<bool> setStringList(String key, List<String> value) async { _map[key] = value; return true; }
}