part of '/quran.dart';

/// Search tab inside the [QuranHubSheet] — full-text ayah search +
/// surah-name search, results below the input. Slice 3 wires up
/// `QuranLibrary().search` / `surahSearch`, with debouncing and a
/// keyboard-aware list that grows when the soft keyboard appears.
class QuranHubSearchPanel extends StatelessWidget {
  final QuranThemePalette palette;
  final String languageCode;

  const QuranHubSearchPanel({
    super.key,
    required this.palette,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    return _PanelPlaceholder(
      palette: palette,
      message: languageCode == 'ar'
          ? 'بحث في الآيات والسور قريبًا'
          : 'Ayah + surah search coming up',
    );
  }
}
