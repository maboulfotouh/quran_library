part of '/quran.dart';

/// Compact action sheet shown when the consumer wires a tap on an
/// ayah in the reader. Replaces the legacy floating long-press
/// menu — both visually (a familiar modal bottom sheet instead of
/// a positioned dialog the user often missed) and behaviourally
/// (tap, not long-press, since most users never discovered the
/// long-press gesture).
///
/// Four primary actions in a single row:
///   * **Play** — plays the ayah via `AudioCtrl.playSingleAyah`.
///   * **Tafsir** — opens [InlineTafsirSheet] for the same ayah.
///   * **Bookmark** — opens [BookmarkColorSheet] to pick a colour
///     and persist via `BookmarksCtrl.saveBookmark`.
///   * **Copy** — copies the ayah text to the clipboard.
///
/// The sheet is small (height = wrap-content), themed via
/// [QuranThemePalette], and dismissible via tap-outside / drag /
/// the corner X button. The Tafsir and Bookmark actions navigate
/// to follow-up sheets which re-enter the modal stack — the
/// original sheet is closed first so the user only ever sees one
/// modal at a time.
class AyahActionSheet extends StatelessWidget {
  /// The ayah the user tapped — drives the row's subtitle
  /// ("Ayah 42 · Page 5") and powers the Play / Tafsir / Copy
  /// actions.
  final AyahModel ayah;

  /// Page index this ayah belongs to (0-based) — used by
  /// `InlineTafsirSheet` to load the right tafsir page.
  final int pageIndex;

  /// Locale code for sheet labels.
  final String languageCode;

  /// Optional play callback override. When null, no Play button
  /// is rendered — consumers without an audio pipeline can opt
  /// out cleanly.
  final Future<void> Function(AyahModel ayah)? onPlay;

  const AyahActionSheet({
    super.key,
    required this.ayah,
    required this.pageIndex,
    required this.languageCode,
    this.onPlay,
  });

  /// Convenience open helper. Returns a Future so callers can
  /// await the dismissal (useful if the consumer wants to chain
  /// follow-up state changes).
  static Future<void> show(
    BuildContext context, {
    required AyahModel ayah,
    required int pageIndex,
    String languageCode = 'en',
    Future<void> Function(AyahModel ayah)? onPlay,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66000000),
      builder: (_) => AyahActionSheet(
        ayah: ayah,
        pageIndex: pageIndex,
        languageCode: languageCode,
        onPlay: onPlay,
      ),
    );
  }

  bool get _isAr => languageCode == 'ar';

  @override
  Widget build(BuildContext context) {
    return GetBuilder<QuranCtrl>(
      builder: (ctrl) => Obx(() {
        final palette = ctrl.state.quranTheme.value.palette;
        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHandle(palette: palette),
              _AyahLabel(palette: palette, ayah: ayah, isAr: _isAr),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    if (onPlay != null) ...[
                      Expanded(
                        child: _ActionButton(
                          palette: palette,
                          icon: Icons.play_arrow_rounded,
                          label: _isAr ? 'استماع' : 'Play',
                          onTap: () async {
                            Navigator.of(context).maybePop();
                            await onPlay!(ayah);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: _ActionButton(
                        palette: palette,
                        icon: Icons.menu_book_rounded,
                        label: _isAr ? 'التفسير' : 'Tafsir',
                        onTap: () {
                          Navigator.of(context).maybePop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            InlineTafsirSheet.show(
                              context,
                              ayah: ayah,
                              pageIndex: pageIndex,
                              languageCode: languageCode,
                            );
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        palette: palette,
                        icon: Icons.bookmark_add_rounded,
                        label: _isAr ? 'فاصل' : 'Bookmark',
                        onTap: () {
                          Navigator.of(context).maybePop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            BookmarkColorSheet.show(
                              context,
                              ayah: ayah,
                              languageCode: languageCode,
                            );
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        palette: palette,
                        icon: Icons.copy_rounded,
                        label: _isAr ? 'نسخ' : 'Copy',
                        onTap: () async {
                          await Clipboard.setData(
                              ClipboardData(text: ayah.text));
                          if (context.mounted) {
                            Navigator.of(context).maybePop();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  final QuranThemePalette palette;
  const _SheetHandle({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: AlignmentDirectional.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: palette.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 0, end: 4,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkResponse(
              onTap: () => Navigator.of(context).maybePop(),
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

class _AyahLabel extends StatelessWidget {
  final QuranThemePalette palette;
  final AyahModel ayah;
  final bool isAr;

  const _AyahLabel({
    required this.palette,
    required this.ayah,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    // surahNumber on AyahModel is sometimes hydrated lazily — fall
    // back to the page number so the subtitle is always useful.
    final surahNumber = ayah.surahNumber;
    final surahName = surahNumber != null
        ? QuranCtrl.instance.surahsList
            .firstWhereOrNull((s) => s.number == surahNumber)
        : null;
    final subtitle = surahName != null
        ? (isAr
            ? '${surahName.name} · آية ${ayah.ayahNumber}'
            : '${surahName.englishName} · Ayah ${ayah.ayahNumber}')
        : (isAr
            ? 'الآية ${ayah.ayahNumber} · صفحة ${ayah.page}'
            : 'Ayah ${ayah.ayahNumber} · Page ${ayah.page}');
    // Render the preview in the page's actual Quran font so the
    // glyphs look the same as on the page the user tapped — the
    // default system font for Arabic was unrecognisable as
    // "this is the ayah I just picked".
    final fontFamily = QuranCtrl.instance
        .getFontPath(ayah.page - 1,
            isDark: QuranCtrl.instance.state.quranTheme.value.isDark);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: palette.subInk,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          // A 2-line preview of the ayah text so the user has a
          // little context for "is this the ayah I tapped?".
          Text(
            ayah.text,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: fontFamily,
              package: 'quran_library',
              fontSize: 19,
              color: palette.ink,
              height: 1.75,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final QuranThemePalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
              palette.accent.withValues(alpha: 0.06), palette.surface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: palette.accent, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: palette.ink,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
