part of '/quran.dart';

/// Small follow-up sheet shown when the user taps "Bookmark" in
/// [AyahActionSheet]. Renders the three default bookmark colours
/// (gold / red / green) and persists the picked colour through
/// `BookmarksCtrl.saveBookmark`. The choice is intentionally a
/// short menu — keeping the palette tight keeps the bookmarks
/// tab readable instead of a soup of random hexes.
class BookmarkColorSheet extends StatelessWidget {
  final AyahModel ayah;
  final String languageCode;

  /// Colours that match the legacy menu's defaults — keeping them
  /// the same means existing bookmarks group cleanly with new
  /// ones in the [QuranHubBookmarksPanel] colour buckets.
  static const _defaultColors = <int>[
    0xAAFFD354, // gold
    0xAAF36077, // red
    0xAA00CD00, // green
  ];

  const BookmarkColorSheet({
    super.key,
    required this.ayah,
    this.languageCode = 'en',
  });

  static Future<void> show(
    BuildContext context, {
    required AyahModel ayah,
    String languageCode = 'en',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66000000),
      builder: (_) => BookmarkColorSheet(
        ayah: ayah,
        languageCode: languageCode,
      ),
    );
  }

  bool get _isAr => languageCode == 'ar';

  @override
  Widget build(BuildContext context) {
    return GetBuilder<QuranCtrl>(
      builder: (ctrl) => Obx(() {
        final palette = ctrl.state.quranTheme.value.palette;
        final surahName = ctrl.getSurahDataByAyah(ayah).arabicName;
        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: palette.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: Text(
                  _isAr ? 'اختر لون الفاصل' : 'Pick a bookmark colour',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: palette.ink,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Text(
                  _isAr
                      ? 'سيُحفَظ تحت هذا اللون داخل تبويب الفواصل.'
                      : 'Saved under this colour in the Bookmarks tab.',
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.subInk,
                    height: 1.4,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    for (final code in _defaultColors) ...[
                      Expanded(
                        child: _ColourSwatch(
                          palette: palette,
                          colour: Color(code),
                          onTap: () {
                            BookmarksCtrl.instance.saveBookmark(
                              surahName: surahName,
                              ayahNumber: ayah.ayahNumber,
                              ayahId: ayah.ayahUQNumber,
                              page: ayah.page,
                              colorCode: code,
                            );
                            Navigator.of(context).maybePop();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ]..removeLast(),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _ColourSwatch extends StatelessWidget {
  final QuranThemePalette palette;
  final Color colour;
  final VoidCallback onTap;

  const _ColourSwatch({
    required this.palette,
    required this.colour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: colour,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.divider),
        ),
        child: Center(
          child: Icon(
            Icons.bookmark_rounded,
            color: palette.ink,
            size: 22,
          ),
        ),
      ),
    );
  }
}
