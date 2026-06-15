part of '/quran.dart';

/// Bookmarks (fawasl) tab inside the [QuranHubSheet] — grouped by
/// the colored markers the user picked in the legacy ayah menu.
/// Slice 3 reads `BookmarksCtrl.bookmarksAyahs` and groups by
/// `colorCode`, with tap-to-jump-and-close behaviour.
class QuranHubBookmarksPanel extends StatelessWidget {
  final QuranThemePalette palette;
  final String languageCode;

  const QuranHubBookmarksPanel({
    super.key,
    required this.palette,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    return _PanelPlaceholder(
      palette: palette,
      message: languageCode == 'ar'
          ? 'فواصلك مع التصنيف بالألوان قريبًا'
          : 'Bookmarks grouped by colour coming up',
    );
  }
}
