part of '/quran.dart';

/// Index tab inside the [QuranHubSheet] — surah list plus jump-to-
/// juz' / page affordances. Slice 3 swaps the placeholder out for
/// the actual surah list + juz' jumper extracted from the legacy
/// `IndexTabWidget`.
class QuranHubIndexPanel extends StatelessWidget {
  final QuranThemePalette palette;
  final String languageCode;

  const QuranHubIndexPanel({
    super.key,
    required this.palette,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    return _PanelPlaceholder(
      palette: palette,
      message: languageCode == 'ar'
          ? 'فهرس السور والأجزاء قريبًا'
          : 'Surahs and juz\' jumper coming up',
    );
  }
}
