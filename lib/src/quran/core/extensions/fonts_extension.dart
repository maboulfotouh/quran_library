part of '/quran.dart';

/// Extension to handle font-related operations for the QuranCtrl class.
///
/// الخطوط تُحمّل ديناميكيًا عبر [QuranFontsService] من ملفات `.ttf.gz`
/// مضغوطة في الـ assets.
///
/// [iqama fork] Only the PRIMARY variant (`page${N}`) is loaded during
/// bulk download — generating all five variants up-front meant ~3,020
/// platform-thread `loadFontFromList` calls plus thousands of CPAL
/// byte mutations, and that's what made fresh downloads feel stuck.
/// Derived variants (dark / no-tajweed / red) are generated the first
/// time the renderer asks for them; the helper below transparently
/// kicks that off and falls back to the primary family in the
/// meantime so the page never shows the system font.
extension FontsExtension on QuranCtrl {
  /// Family name to feed into Text/RichText for the given page.
  /// Renders the primary while a non-primary variant is being
  /// generated — once the variant registers, `update(['fonts'])`
  /// triggers a rebuild that re-resolves to the variant family.
  String getFontPath(int pageIndex, {bool isDark = false}) {
    final withTajweed = state.isTajweedEnabled.value;
    final FontVariant? want = withTajweed
        ? (isDark ? FontVariant.dark : null)
        : (isDark ? FontVariant.noTajweedDark : FontVariant.noTajweed);
    return _resolveFamily(pageIndex, want);
  }

  /// Red variant for the ten-readings disagreement words.
  String getRedFontPath(int pageIndex) =>
      _resolveFamily(pageIndex, FontVariant.red);

  /// Returns the family to render with. `null` variant = primary —
  /// always registered after bulk download, so a sync return is safe.
  /// For derived variants: returns the variant if registered, else
  /// kicks off ensureVariant in the background and returns primary
  /// as a temporary fallback.
  ///
  /// [iqama fork] When the variant lands we update ONLY the specific
  /// page's GetBuilder (`qpc_page_$pageIndex`) — the previous
  /// `update(['_pageViewBuild'])` rebuilt every PageViewBuild in
  /// the PageView's keep-alive window (~9 pages with preloadPagesCount=4).
  /// With `fontsRevision` in the rich-text-line fingerprint, each
  /// of those 9 page rebuilds invalidated 15 line caches → ~135
  /// line builds per variant registration, and ~2700 per
  /// prewarm pass — easily a second of main-thread cost while the
  /// user was trying to swipe. The targeted update touches only
  /// the page whose variant just registered; other pages re-resolve
  /// their family naturally on their own next build.
  String _resolveFamily(int pageIndex, FontVariant? variant) {
    final page = pageIndex + 1;
    if (variant == null) return QuranFontsService.getFontFamily(pageIndex);
    final family = variant.familyFor(page);
    if (QuranFontsService.isFamilyReady(family)) return family;
    QuranFontsService.ensureVariant(page, variant).then((_) {
      try {
        // ignore: invalid_use_of_protected_member
        update(['qpc_page_$pageIndex']);
      } catch (_) {/* controller may have been disposed */}
    });
    return QuranFontsService.getFontFamily(pageIndex);
  }
}
