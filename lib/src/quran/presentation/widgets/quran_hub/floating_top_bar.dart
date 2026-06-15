part of '/quran.dart';

/// The minimal reader chrome that ships with the new UX. A single
/// rounded pill floats at the top of the page; everything the user
/// can do globally on the reader is reachable from here:
///
///   - [<]  back / close
///   - page number + active surah (read-only label, taps the Hub
///     on the Surahs tab as a convenience)
///   - [☼] / [☾] / [☕] theme cycle (Light → Dark → Sepia → Light)
///   - [≡] open Hub
///
/// **Visibility.** Tied to `quranCtrl.isShowControl` — the same
/// flag the page-tap gesture toggles — and slides in/out on the
/// same 200 ms ease curve as the legacy chrome did. So the
/// reading experience stays unchanged: tap-to-hide chrome,
/// tap-again-to-show.
///
/// **Per-tap actions only.** The pill itself is wrapped in a
/// no-op GestureDetector with `behavior: opaque` so a tap on the
/// gap between buttons does NOT also toggle the page chrome —
/// otherwise a user trying to read the page number would hide
/// the bar.
class QuranFloatingTopBar extends StatelessWidget {
  /// Locale code for the surah-name label — 'ar' / 'en'.
  final String languageCode;

  /// Optional back button override — when null, the bar uses
  /// `Navigator.maybePop` (the standard behaviour for a reader
  /// pushed on top of a stack). Consumers wrap their own
  /// dismiss logic here when they need to do extra cleanup
  /// (e.g. save the current page before closing).
  final VoidCallback? onBack;

  const QuranFloatingTopBar({
    super.key,
    required this.languageCode,
    this.onBack,
  });

  bool get _isAr => languageCode == 'ar';

  @override
  Widget build(BuildContext context) {
    return GetBuilder<QuranCtrl>(
      builder: (ctrl) => Obx(() {
        final visible = ctrl.isShowControl.value;
        final palette = ctrl.state.quranTheme.value.palette;
        final mq = MediaQuery.of(context);
        return AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          offset: visible ? Offset.zero : const Offset(0, -1.4),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: visible ? 1 : 0,
            child: Padding(
              padding: EdgeInsets.only(
                top: mq.padding.top + 6,
                left: 10,
                right: 10,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Eat taps on the empty pill area so a user trying
                  // to read the page-number label can't accidentally
                  // collapse the chrome with a stray tap.
                  onTap: () {},
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: palette.divider),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PillIconButton(
                          palette: palette,
                          icon: _isAr
                              ? Icons.arrow_forward_rounded
                              : Icons.arrow_back_rounded,
                          tooltip: _isAr ? 'رجوع' : 'Back',
                          onTap: onBack ??
                              () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 2),
                        _PageLabel(
                          palette: palette,
                          languageCode: languageCode,
                          isAr: _isAr,
                          onTap: () => QuranHubSheet.show(
                            context,
                            languageCode: languageCode,
                            initialTab: QuranHubTab.surahs,
                          ),
                        ),
                        const SizedBox(width: 2),
                        _ThemeCycleButton(
                          palette: palette,
                          currentMode: ctrl.state.quranTheme.value,
                          onTap: ctrl.cycleQuranTheme,
                        ),
                        const SizedBox(width: 2),
                        _PillIconButton(
                          palette: palette,
                          icon: Icons.tune_rounded,
                          tooltip: _isAr ? 'الإعدادات والفهرس' : 'Hub',
                          onTap: () => QuranHubSheet.show(
                            context,
                            languageCode: languageCode,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Mid-pill label — page number + active surah name. Tapping it
/// opens the Hub on the Surahs tab; the action is the same as a
/// dedicated "list" button but keeps the chrome density low.
class _PageLabel extends StatelessWidget {
  final QuranThemePalette palette;
  final String languageCode;
  final bool isAr;
  final VoidCallback onTap;

  const _PageLabel({
    required this.palette,
    required this.languageCode,
    required this.isAr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ctrl = QuranCtrl.instance;
      final page = ctrl.state.currentPageNumber.value;
      // Surah for the current page — surahsList is keyed by index,
      // QuranLibrary().getSurahNameFromPage is the safe accessor.
      final surahName = _surahNameForPage(ctrl, page);
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                isAr ? 'صفحة $page' : 'Page $page',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: palette.ink,
                  letterSpacing: -0.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (surahName != null) ...[
                const SizedBox(height: 1),
                Text(
                  surahName,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: palette.subInk,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  /// Pulls the surah name that "owns" the current page from the
  /// loaded surahsList. Returns null if the controller hasn't
  /// hydrated yet — the label silently collapses to just the
  /// page number in that case.
  String? _surahNameForPage(QuranCtrl ctrl, int page) {
    if (ctrl.surahsList.isEmpty) return null;
    // Find the first surah whose start page is <= current page.
    // The loop is at most 114 iterations and runs on every tick
    // — cheap enough to do inline without memoisation.
    final pageAyahs = ctrl.getCurrentPageAyahsSeparatedForBasmalah(page - 1);
    if (pageAyahs.isEmpty) return null;
    final first = pageAyahs.first.firstOrNull;
    final surahNumber = first?.surahNumber ?? 1;
    final s = ctrl.surahsList.firstWhereOrNull((x) => x.number == surahNumber);
    if (s == null) return null;
    return isAr ? s.name : s.englishName;
  }
}

class _PillIconButton extends StatelessWidget {
  final QuranThemePalette palette;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _PillIconButton({
    required this.palette,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: palette.ink),
          ),
        ),
      ),
    );
  }
}

class _ThemeCycleButton extends StatelessWidget {
  final QuranThemePalette palette;
  final QuranThemeMode currentMode;
  final VoidCallback onTap;

  const _ThemeCycleButton({
    required this.palette,
    required this.currentMode,
    required this.onTap,
  });

  IconData get _icon => switch (currentMode) {
        QuranThemeMode.light => Icons.light_mode_rounded,
        QuranThemeMode.dark  => Icons.dark_mode_rounded,
        QuranThemeMode.sepia => Icons.local_cafe_rounded,
      };

  String _tooltip(bool isAr) {
    // Tooltip describes what tapping does — the *next* mode.
    final next = switch (currentMode) {
      QuranThemeMode.light => isAr ? 'الوضع الداكن'  : 'Dark mode',
      QuranThemeMode.dark  => isAr ? 'الوضع البُني'  : 'Sepia mode',
      QuranThemeMode.sepia => isAr ? 'الوضع الفاتح' : 'Light mode',
    };
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    return _PillIconButton(
      palette: palette,
      icon: _icon,
      tooltip: _tooltip(isAr),
      onTap: onTap,
    );
  }
}
