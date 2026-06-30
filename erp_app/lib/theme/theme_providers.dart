import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/prefs/view_prefs_service.dart';

// ── Accent presets ────────────────────────────────────────────────────────────

const List<({Color color, String label})> kAccentPresets = [
  (color: Color(0xFF5E6AD2), label: 'Linear'),
  (color: Color(0xFF3B82F6), label: 'Blue'),
  (color: Color(0xFF10B981), label: 'Emerald'),
  (color: Color(0xFFF59E0B), label: 'Amber'),
  (color: Color(0xFFEF4444), label: 'Red'),
  (color: Color(0xFFEC4899), label: 'Pink'),
];

const _kAccentKey      = 'theme.accent';
const _kModeKey        = 'theme.mode';
const _kDarkShadeKey   = 'theme.darkShade';
const _kLightShadeKey  = 'theme.lightShade';
const _kFontFamilyKey  = 'theme.fontFamily';
const _kFontSizeKey    = 'theme.fontSize';

// ── Accent ────────────────────────────────────────────────────────────────────

class AccentColorNotifier extends Notifier<Color> {
  @override
  Color build() {
    _load();
    return kAccentPresets.first.color;
  }

  Future<void> _load() async {
    final value = await ViewPrefsService.getInt(_kAccentKey);
    if (value != null) state = Color(value);
  }

  Future<void> setAccent(Color color) async {
    state = color;
    await ViewPrefsService.setInt(_kAccentKey, color.toARGB32());
  }
}

final accentColorProvider =
    NotifierProvider<AccentColorNotifier, Color>(AccentColorNotifier.new);

// ── Theme mode ────────────────────────────────────────────────────────────────

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.dark;
  }

  Future<void> _load() async {
    final value = await ViewPrefsService.getString(_kModeKey);
    if (value != null) {
      state = ThemeMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => ThemeMode.dark,
      );
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ViewPrefsService.setString(_kModeKey, mode.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// ── Surface shade presets ─────────────────────────────────────────────────────

typedef LinearShadePreset = ({
  Color pageBg,
  Color surfaceBase,
  Color surfaceRaised,
  String label,
});

const List<LinearShadePreset> kDarkShadePresets = [
  (pageBg: Color(0xFF000000), surfaceBase: Color(0xFF0A0A0A), surfaceRaised: Color(0xFF141414), label: 'Black'),
  (pageBg: Color(0xFF080808), surfaceBase: Color(0xFF0F0F10), surfaceRaised: Color(0xFF181818), label: 'Near'),
  (pageBg: Color(0xFF0D0D0D), surfaceBase: Color(0xFF131315), surfaceRaised: Color(0xFF1C1C1E), label: 'Default'),
  (pageBg: Color(0xFF141416), surfaceBase: Color(0xFF1A1A1C), surfaceRaised: Color(0xFF242426), label: 'Dim'),
  (pageBg: Color(0xFF1C1C1E), surfaceBase: Color(0xFF222224), surfaceRaised: Color(0xFF2C2C2E), label: 'Soft'),
];

const List<LinearShadePreset> kLightShadePresets = [
  (pageBg: Color(0xFFF5F5F7), surfaceBase: Color(0xFFFFFFFF), surfaceRaised: Color(0xFFEFEFF1), label: 'Bright'),
  (pageBg: Color(0xFFEFEFF1), surfaceBase: Color(0xFFF9F9FB), surfaceRaised: Color(0xFFE9E9EB), label: 'Soft'),
  (pageBg: Color(0xFFEAEAEC), surfaceBase: Color(0xFFF4F4F6), surfaceRaised: Color(0xFFE4E4E6), label: 'Default'),
  (pageBg: Color(0xFFE4E4E6), surfaceBase: Color(0xFFEEEEF0), surfaceRaised: Color(0xFFDEDEE0), label: 'Cool'),
  (pageBg: Color(0xFFDEDEE0), surfaceBase: Color(0xFFE8E8EA), surfaceRaised: Color(0xFFD8D8DA), label: 'Stone'),
];

// ── Dark shade ────────────────────────────────────────────────────────────────

class DarkShadeNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return 2;
  }

  Future<void> _load() async {
    final value = await ViewPrefsService.getInt(_kDarkShadeKey);
    if (value != null && value >= 0 && value < kDarkShadePresets.length) {
      state = value;
    }
  }

  Future<void> setShade(int index) async {
    state = index;
    await ViewPrefsService.setInt(_kDarkShadeKey, index);
  }
}

final darkShadeProvider =
    NotifierProvider<DarkShadeNotifier, int>(DarkShadeNotifier.new);

// ── Light shade ───────────────────────────────────────────────────────────────

class LightShadeNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return 2;
  }

  Future<void> _load() async {
    final value = await ViewPrefsService.getInt(_kLightShadeKey);
    if (value != null && value >= 0 && value < kLightShadePresets.length) {
      state = value;
    }
  }

  Future<void> setShade(int index) async {
    state = index;
    await ViewPrefsService.setInt(_kLightShadeKey, index);
  }
}

final lightShadeProvider =
    NotifierProvider<LightShadeNotifier, int>(LightShadeNotifier.new);

// ── Font family ───────────────────────────────────────────────────────────────

const List<({String family, String label})> kFontPresets = [
  (family: 'Inter',             label: 'Inter'),
  (family: 'DM Sans',           label: 'DM Sans'),
  (family: 'Plus Jakarta Sans', label: 'Jakarta'),
  (family: 'IBM Plex Sans',     label: 'IBM Plex'),
  (family: 'Roboto',            label: 'Roboto'),
];

class FontFamilyNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return kFontPresets.first.family;
  }

  Future<void> _load() async {
    final value = await ViewPrefsService.getString(_kFontFamilyKey);
    if (value != null && kFontPresets.any((p) => p.family == value)) {
      state = value;
    }
  }

  Future<void> setFamily(String family) async {
    state = family;
    await ViewPrefsService.setString(_kFontFamilyKey, family);
  }
}

final fontFamilyProvider =
    NotifierProvider<FontFamilyNotifier, String>(FontFamilyNotifier.new);

// ── Font size ─────────────────────────────────────────────────────────────────

const List<({double scale, String label})> kFontSizePresets = [
  (scale: 0.875,  label: 'XS'),
  (scale: 0.9375, label: 'S'),
  (scale: 1.0,    label: 'M'),
  (scale: 1.125,  label: 'L'),
];

class FontSizeNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return 2;
  }

  Future<void> _load() async {
    final value = await ViewPrefsService.getInt(_kFontSizeKey);
    if (value != null && value >= 0 && value < kFontSizePresets.length) {
      state = value;
    }
  }

  Future<void> setSize(int index) async {
    state = index;
    await ViewPrefsService.setInt(_kFontSizeKey, index);
  }
}

final fontSizeProvider =
    NotifierProvider<FontSizeNotifier, int>(FontSizeNotifier.new);
