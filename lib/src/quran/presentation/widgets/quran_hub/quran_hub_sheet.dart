part of '/quran.dart';

/// The unified controls surface for the reader — a single bottom
/// sheet with five tabs (Index / Bookmarks / Search / Downloads /
/// Settings) that replaces the legacy
/// `IndexTab / SearchTab / BookmarksTab / SurahAudioScreen /
/// TajweedMenu / DisplayModeBar` constellation.
///
/// **Why one sheet?** The legacy UX scattered controls across the
/// top bar, a right-edge vertical bar, multiple modals, and an
/// entirely separate audio screen. Users couldn't tell where
/// "switch to dark mode" or "download a surah" lived. A single
/// sheet with named tabs makes the inventory obvious and lets
/// every action be reached with at most two taps from the reader.
///
/// **Theme awareness.** The whole sheet reads from
/// `QuranCtrl.instance.currentPalette` via a `GetBuilder` so a
/// Light → Dark → Sepia cycle on the top bar reskins the Hub
/// instantly. No widget tree rebuild on the host side needed.
///
/// **Entry point.** Open with [QuranHubSheet.show] — wraps
/// `showModalBottomSheet` with our standard look (drag handle,
/// close button, ~85% height) and passes an optional
/// [initialTab] for callers that want to deep-link straight to
/// a panel (e.g. a search affordance on the top bar could open
/// the sheet on the Search tab).
///
/// **Independence from the host.** Translations come from a small
/// inline label map keyed by `languageCode` (passed in by the
/// consumer — salah-league-mobile threads its current locale code).
/// That avoids requiring an l10n delegate from outside.
enum QuranHubTab {
  // `surahs` rather than the more natural `index` — the latter
  // collides with Dart's built-in `Enum.index` getter.
  surahs,
  bookmarks,
  search,
  downloads,
  settings;

  /// Localized label for the tab chip. Kept inline so consumers
  /// don't have to pipe ARB strings through the library API.
  String label(String languageCode) {
    final isAr = languageCode == 'ar';
    return switch (this) {
      QuranHubTab.surahs     => isAr ? 'الفهرس'    : 'Index',
      QuranHubTab.bookmarks => isAr ? 'الفواصل'   : 'Bookmarks',
      QuranHubTab.search    => isAr ? 'البحث'     : 'Search',
      QuranHubTab.downloads => isAr ? 'التحميلات' : 'Downloads',
      QuranHubTab.settings  => isAr ? 'الإعدادات' : 'Settings',
    };
  }

  IconData get icon => switch (this) {
        QuranHubTab.surahs     => Icons.menu_book_rounded,
        QuranHubTab.bookmarks => Icons.bookmark_rounded,
        QuranHubTab.search    => Icons.search_rounded,
        QuranHubTab.downloads => Icons.download_rounded,
        QuranHubTab.settings  => Icons.tune_rounded,
      };
}

class QuranHubSheet extends StatefulWidget {
  final QuranHubTab initialTab;

  /// Locale code for the sheet's static labels — 'ar' / 'en'.
  /// Threaded down from the consumer (salah-league-mobile passes
  /// `Localizations.localeOf(context).languageCode`).
  final String languageCode;

  const QuranHubSheet({
    super.key,
    this.initialTab = QuranHubTab.surahs,
    this.languageCode = 'en',
  });

  /// Open the Hub as a modal bottom sheet. Fills ~85% of the
  /// viewport — enough to show a full surah list / bookmarks /
  /// search results without scrolling the chrome with them.
  ///
  /// [initialTab] lets a caller deep-link to a panel. The reader's
  /// top-bar search button, for example, opens the sheet on
  /// [QuranHubTab.search] so the user's next tap can be the query.
  static Future<void> show(
    BuildContext context, {
    QuranHubTab initialTab = QuranHubTab.surahs,
    String languageCode = 'en',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66000000),
      // Keep the sheet flush to the top of available area so we can
      // bring the keyboard up for Search without it pushing the sheet
      // chrome off-screen on small phones.
      builder: (ctx) => QuranHubSheet(
        initialTab: initialTab,
        languageCode: languageCode,
      ),
    );
  }

  @override
  State<QuranHubSheet> createState() => _QuranHubSheetState();
}

class _QuranHubSheetState extends State<QuranHubSheet> {
  late QuranHubTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<QuranCtrl>(
      // Rebuild when the theme or core state changes — palette flips
      // and font / display-mode changes ripple through the panels.
      builder: (ctrl) => Obx(() {
        final palette = ctrl.state.quranTheme.value.palette;
        final languageCode = widget.languageCode;
        final mq = MediaQuery.of(context);

        return Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: mq.size.height * 0.85,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HubHeader(
                    palette: palette,
                    onClose: () => Navigator.of(context).maybePop(),
                  ),
                  _HubTabStrip(
                    palette: palette,
                    languageCode: languageCode,
                    active: _tab,
                    onChange: (next) => setState(() => _tab = next),
                  ),
                  Divider(height: 1, color: palette.divider),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _panelFor(_tab,
                          palette: palette, languageCode: languageCode),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _panelFor(QuranHubTab tab,
      {required QuranThemePalette palette, required String languageCode}) {
    // Keyed so AnimatedSwitcher knows when to cross-fade — without
    // ValueKey it would treat all _Placeholder instances as identical
    // and skip the transition.
    return KeyedSubtree(
      key: ValueKey(tab),
      child: switch (tab) {
        QuranHubTab.surahs =>
          QuranHubIndexPanel(palette: palette, languageCode: languageCode),
        QuranHubTab.bookmarks =>
          QuranHubBookmarksPanel(palette: palette, languageCode: languageCode),
        QuranHubTab.search =>
          QuranHubSearchPanel(palette: palette, languageCode: languageCode),
        QuranHubTab.downloads =>
          QuranHubDownloadsPanel(palette: palette, languageCode: languageCode),
        QuranHubTab.settings =>
          QuranHubSettingsPanel(palette: palette, languageCode: languageCode),
      },
    );
  }
}

/// Top of the Hub: drag pill in the centre + small close button in
/// the top-end corner. Both pop the sheet so the user has a tap,
/// a swipe-down, AND an explicit X to choose from.
class _HubHeader extends StatelessWidget {
  final QuranThemePalette palette;
  final VoidCallback onClose;

  const _HubHeader({required this.palette, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: AlignmentDirectional.topCenter,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          onVerticalDragEnd: (d) {
            final v = d.primaryVelocity;
            if (v != null && v > 240) onClose();
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 0,
          end: 4,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkResponse(
              onTap: onClose,
              radius: 18,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close_rounded,
                    size: 16, color: palette.subInk),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The five top-of-sheet chip-style tabs. Each is icon + label
/// stacked vertically; the active one gets a tinted background and
/// accent colour. Horizontal scroll for narrow phones.
class _HubTabStrip extends StatelessWidget {
  final QuranThemePalette palette;
  final String languageCode;
  final QuranHubTab active;
  final ValueChanged<QuranHubTab> onChange;

  const _HubTabStrip({
    required this.palette,
    required this.languageCode,
    required this.active,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (final tab in QuranHubTab.values) ...[
              _HubTabChip(
                tab: tab,
                isActive: tab == active,
                palette: palette,
                languageCode: languageCode,
                onTap: () => onChange(tab),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _HubTabChip extends StatelessWidget {
  final QuranHubTab tab;
  final bool isActive;
  final QuranThemePalette palette;
  final String languageCode;
  final VoidCallback onTap;

  const _HubTabChip({
    required this.tab,
    required this.isActive,
    required this.palette,
    required this.languageCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isActive
        ? Color.alphaBlend(palette.accent.withValues(alpha: 0.12), palette.surface)
        : Colors.transparent;
    final fg = isActive ? palette.accent : palette.subInk;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? palette.accent : palette.divider,
            width: isActive ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              tab.label(languageCode),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
