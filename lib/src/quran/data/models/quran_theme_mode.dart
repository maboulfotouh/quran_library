part of '/quran.dart';

/// Three reading themes the user can cycle through from the floating
/// top bar of the reader, independent of the host app's global theme.
///
/// **Why a Quran-only theme?** A user who likes a bright app overall
/// may still want a low-glare reading surface in the early morning or
/// at night — and a daytime reader may want the warm parchment feel
/// of sepia. Coupling this to the host app's `themeMode` would force
/// every screen to flip together.
///
/// Persisted via GetStorage under [QuranThemeStorage.key] so the
/// choice survives kill+relaunch. Mutation lives on [QuranCtrl]
/// (`setQuranTheme` / `cycleQuranTheme`) which both writes storage
/// and pushes the new value through `state.quranTheme` so every
/// listening widget rebuilds with the new palette.
///
/// **isDark routing.** The existing fonts pipeline branches on a
/// single `isDark` bool — see [QuranThemeMode.isDark]. Sepia is
/// "light-on-warm", so it routes through the light font variant.
enum QuranThemeMode {
  /// Crisp white background, near-black ink. Default for fresh installs.
  light,

  /// Near-black background, off-white ink. Routes through the dark
  /// font variant (cool gray glyphs) and dims the page chrome.
  dark,

  /// Warm parchment background (#F5EDD8) with brown ink. Routes
  /// through the light font variant — the warmth comes from the
  /// surface colour, not from a recoloured glyph CPAL.
  sepia;

  /// True when this theme renders against a dark background — the
  /// fonts pipeline reads this to decide between the light and dark
  /// glyph variants. Sepia is "warm-on-light" so it stays in the
  /// light branch.
  bool get isDark => this == QuranThemeMode.dark;

  /// Concrete palette for this mode. Constructed once and treated as
  /// immutable; widgets pass the palette down via inherited widget
  /// chain or read straight from the QuranCtrl.
  QuranThemePalette get palette => switch (this) {
        QuranThemeMode.light => QuranThemePalette.light,
        QuranThemeMode.dark  => QuranThemePalette.dark,
        QuranThemeMode.sepia => QuranThemePalette.sepia,
      };
}

/// Concrete color tokens for a single reader theme. Widgets read
/// these instead of hard-coding colours so swapping a theme
/// reskins the whole reader without touching widget code.
///
/// **Why a flat token set instead of ThemeData?** The Quran reader
/// chrome is small and bespoke — a full ThemeData would carry 200+
/// fields we don't use. A flat record-style class keeps the token
/// surface small and discoverable.
class QuranThemePalette {
  /// The page (mushaf) background — the colour behind the glyphs.
  final Color pageBackground;

  /// Sheet / dialog / floating-pill surface colour.
  final Color surface;

  /// Body ink colour used by labels in the chrome (page number,
  /// surah name, tab labels). Not the glyph colour — that comes
  /// from the loaded CPAL font variant.
  final Color ink;

  /// Secondary ink — used for "ayah 42 of 286" subtitles, hints.
  final Color subInk;

  /// Divider lines on the chrome.
  final Color divider;

  /// Accent — the Iqama teal in light/dark, a deeper rust in sepia
  /// so the chrome harmonises with the parchment background.
  final Color accent;

  /// Selected-ayah highlight colour. Tinted accent over page.
  final Color selectionHighlight;

  const QuranThemePalette({
    required this.pageBackground,
    required this.surface,
    required this.ink,
    required this.subInk,
    required this.divider,
    required this.accent,
    required this.selectionHighlight,
  });

  static const light = QuranThemePalette(
    pageBackground:    Color(0xFFFFFFFF),
    surface:           Color(0xFFFFFFFF),
    ink:               Color(0xFF1F1F23),
    subInk:            Color(0xFF6B6B70),
    divider:           Color(0xFFE6E6EA),
    accent:            Color(0xFF1E8E8A),
    selectionHighlight: Color(0x331E8E8A),
  );

  static const dark = QuranThemePalette(
    pageBackground:    Color(0xFF121316),
    surface:           Color(0xFF1B1D22),
    ink:               Color(0xFFEDEDF0),
    subInk:            Color(0xFF9A9AA0),
    divider:           Color(0xFF2A2C32),
    accent:            Color(0xFF59B7B2),
    selectionHighlight: Color(0x3359B7B2),
  );

  static const sepia = QuranThemePalette(
    pageBackground:    Color(0xFFF5EDD8),
    surface:           Color(0xFFEDE3CB),
    ink:               Color(0xFF4B3621),
    subInk:            Color(0xFF7A5F44),
    divider:           Color(0xFFD9CCAE),
    accent:            Color(0xFFB35F3B),
    selectionHighlight: Color(0x33B35F3B),
  );
}

/// Single source of truth for the persistence key. Keeps the
/// storage round-trip honest if the enum is ever renamed.
class QuranThemeStorage {
  QuranThemeStorage._();

  /// GetStorage key the chosen theme is persisted under.
  static const String key = 'quran_theme_mode_v1';

  /// Decodes a stored string back into the enum. Returns null when
  /// the value is missing or doesn't match a known mode — callers
  /// fall back to [QuranThemeMode.light] in that case.
  static QuranThemeMode? decode(Object? raw) {
    if (raw is! String) return null;
    return switch (raw) {
      'light' => QuranThemeMode.light,
      'dark'  => QuranThemeMode.dark,
      'sepia' => QuranThemeMode.sepia,
      _       => null,
    };
  }

  /// Encodes the enum to a storage-friendly string.
  static String encode(QuranThemeMode mode) => switch (mode) {
        QuranThemeMode.light => 'light',
        QuranThemeMode.dark  => 'dark',
        QuranThemeMode.sepia => 'sepia',
      };
}
