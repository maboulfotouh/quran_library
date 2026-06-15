part of '/quran.dart';

/// Downloads tab inside the [QuranHubSheet] — surah-by-surah audio
/// download manager. Slice 3 ports the legacy
/// `AyahDownloadManagerSheet` body in here so the entry point is
/// the Hub instead of a separate full-screen audio screen.
class QuranHubDownloadsPanel extends StatelessWidget {
  final QuranThemePalette palette;
  final String languageCode;

  const QuranHubDownloadsPanel({
    super.key,
    required this.palette,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    return _PanelPlaceholder(
      palette: palette,
      message: languageCode == 'ar'
          ? 'تنزيل السور بصوت القارئ المختار قريبًا'
          : 'Per-surah audio downloads coming up',
    );
  }
}
