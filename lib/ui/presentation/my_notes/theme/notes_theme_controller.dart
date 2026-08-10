import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/foundation.dart';

enum NotesBrightness { dark, light }

/// Persisted Dark/Light preference for My Notes only.
class NotesThemeController extends ChangeNotifier {
  NotesThemeController._();

  static final NotesThemeController instance = NotesThemeController._();

  static const _prefsKey = 'my_notes_theme_brightness';

  NotesBrightness _brightness = NotesBrightness.dark;
  bool _loaded = false;

  NotesBrightness get brightness => _brightness;

  bool get isLight => _brightness == NotesBrightness.light;

  bool get isDark => _brightness == NotesBrightness.dark;

  /// Load once from SharedPreferences (safe to call repeatedly).
  void ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = SharedPref.preferences.getPreferenceString(_prefsKey);
      if (raw == NotesBrightness.light.name) {
        _brightness = NotesBrightness.light;
      } else {
        _brightness = NotesBrightness.dark;
      }
    } catch (_) {
      _brightness = NotesBrightness.dark;
    }
  }

  Future<void> setBrightness(NotesBrightness value) async {
    if (_brightness == value) return;
    _brightness = value;
    // Notify synchronously so notes UI (bottom bar, canvas) flips immediately.
    notifyListeners();
    try {
      await SharedPref.preferences.setPreferencesString(_prefsKey, value.name);
    } catch (e) {
      debugPrint('NotesThemeController: save failed: $e');
    }
  }

  Future<void> toggle() async {
    await setBrightness(
      isLight ? NotesBrightness.dark : NotesBrightness.light,
    );
  }
}
