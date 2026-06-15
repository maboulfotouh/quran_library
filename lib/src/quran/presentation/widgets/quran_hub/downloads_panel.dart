part of '/quran.dart';

/// Downloads tab inside the [QuranHubSheet] — per-surah audio
/// download management for the **currently selected reader**. Each
/// row shows the surah identity (number / Arabic + English names)
/// plus a single trailing affordance: download, delete, or a
/// spinner when a download is in flight.
///
/// Reader picking lives at the top of the panel as a compact
/// banner — the read user picks a reader once and downloads land
/// under that reader's directory. Switching readers re-renders the
/// per-row download state.
///
/// **Why inline instead of pushing a new screen?** Surfaces inside
/// the Hub stay reachable in two taps from the reader. A separate
/// SurahAudioScreen would be a third hop. The cost is that we
/// can't run audio playback from here — that's still the legacy
/// audio slider's job; downloads are the only concern here.
class QuranHubDownloadsPanel extends StatelessWidget {
  final QuranThemePalette palette;
  final String languageCode;

  const QuranHubDownloadsPanel({
    super.key,
    required this.palette,
    required this.languageCode,
  });

  bool get _isAr => languageCode == 'ar';

  @override
  Widget build(BuildContext context) {
    final palette = this.palette;
    return GetBuilder<QuranCtrl>(
      builder: (quranCtrl) {
        final surahs = quranCtrl.surahs;
        if (surahs.isEmpty) {
          return Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(palette.accent),
              ),
            ),
          );
        }
        return Obx(() {
          final audio = AudioCtrl.instance;
          // The ayah downloader (startDownloadAyahSurah) uses the
          // ayah reader list, so we read the ayah index here for
          // the banner — not the surah-mode reader index.
          final readers = ReadersConstants.activeAyahReaders;
          final readerIdx = audio.state.ayahReaderIndex.value;
          final reader = readerIdx >= 0 && readerIdx < readers.length
              ? readers[readerIdx]
              : null;
          // Watching isDownloading drives the spinner state on the
          // active row.
          final isDownloading = audio.state.isDownloading.value;
          return Column(
            children: [
              _ReaderBanner(
                palette: palette,
                isAr: _isAr,
                // ReaderInfo only exposes a single `name` field
                // (Arabic in the bundled constants). We surface it
                // in both languages — there's no English name in
                // the data layer to fall back to.
                readerName: reader?.name,
              ),
              Divider(height: 1, color: palette.divider),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
                  itemCount: surahs.length,
                  itemBuilder: (_, i) {
                    final s = surahs[i];
                    return _SurahDownloadRow(
                      palette: palette,
                      isAr: _isAr,
                      surah: s,
                      anyDownloadInFlight: isDownloading,
                      onDownload: () async {
                        if (audio.state.isDownloading.value) return;
                        await audio.startDownloadAyahSurah(
                          s.surahNumber,
                          context: context,
                        );
                      },
                      onDelete: () =>
                          audio.deleteAyahSurahDownloads(s.surahNumber),
                      isDownloadedChecker: () =>
                          audio.isAyahSurahFullyDownloaded(s.surahNumber),
                    );
                  },
                ),
              ),
            ],
          );
        });
      },
    );
  }
}

class _ReaderBanner extends StatelessWidget {
  final QuranThemePalette palette;
  final bool isAr;
  final String? readerName;

  const _ReaderBanner({
    required this.palette,
    required this.isAr,
    required this.readerName,
  });

  @override
  Widget build(BuildContext context) {
    final name = readerName ?? '—';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                  palette.accent.withValues(alpha: 0.12), palette.surface),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.headphones_rounded,
                color: palette.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isAr ? 'القارئ الحالي' : 'Current reader',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: palette.subInk,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SurahDownloadRow extends StatefulWidget {
  final QuranThemePalette palette;
  final bool isAr;
  final SurahModel surah;
  final bool anyDownloadInFlight;
  final Future<void> Function() onDownload;
  final Future<void> Function() onDelete;
  final Future<bool> Function() isDownloadedChecker;

  const _SurahDownloadRow({
    required this.palette,
    required this.isAr,
    required this.surah,
    required this.anyDownloadInFlight,
    required this.onDownload,
    required this.onDelete,
    required this.isDownloadedChecker,
  });

  @override
  State<_SurahDownloadRow> createState() => _SurahDownloadRowState();
}

class _SurahDownloadRowState extends State<_SurahDownloadRow> {
  bool? _downloaded;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _SurahDownloadRow old) {
    super.didUpdateWidget(old);
    // When the global isDownloading flag flips back to false, a
    // download finished — re-check our state so the icon flips.
    if (old.anyDownloadInFlight && !widget.anyDownloadInFlight) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final v = await widget.isDownloadedChecker();
    if (!mounted) return;
    setState(() => _downloaded = v);
  }

  Future<void> _onTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_downloaded == true) {
        await widget.onDelete();
      } else {
        await widget.onDownload();
      }
    } finally {
      await _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final surah = widget.surah;
    final isDownloaded = _downloaded == true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
              palette.accent.withValues(alpha: 0.03), palette.surface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 30, height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                    palette.accent.withValues(alpha: 0.12), palette.surface),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${surah.surahNumber}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: palette.accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.isAr ? surah.arabicName : surah.englishName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isDownloaded
                        ? (widget.isAr ? 'تم التنزيل' : 'Downloaded')
                        : (widget.isAr ? 'غير محمّل' : 'Not on device'),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDownloaded
                          ? palette.accent
                          : palette.subInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _DownloadButton(
              palette: palette,
              busy: _busy,
              isDownloaded: isDownloaded,
              onTap: _onTap,
              isAr: widget.isAr,
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  final QuranThemePalette palette;
  final bool busy;
  final bool isDownloaded;
  final VoidCallback onTap;
  final bool isAr;

  const _DownloadButton({
    required this.palette,
    required this.busy,
    required this.isDownloaded,
    required this.onTap,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return SizedBox(
        width: 32, height: 32,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(palette.accent),
          ),
        ),
      );
    }
    final icon = isDownloaded
        ? Icons.delete_outline_rounded
        : Icons.download_rounded;
    final fg = isDownloaded ? const Color(0xFFC4524C) : palette.accent;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 20, color: fg),
        ),
      ),
    );
  }
}
