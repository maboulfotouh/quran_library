part of '/quran.dart';

/// Surahs panel inside the [QuranHubSheet] — the single discoverable
/// way to jump anywhere in the mushaf:
///
///   - A name filter at the top (in-place, no separate Search tab
///     needed for "I just want to jump to Al-Baqarah").
///   - A list of all 114 surahs, each row showing the number, the
///     Arabic name, the English transliteration, and the ayah
///     count.
///   - A juz' jumper strip across the bottom — 30 chips for users
///     who think in juz' / hizb instead of surah.
///
/// Tapping anything closes the sheet (`Navigator.maybePop`) and
/// calls `QuranLibrary().jumpToSurah(n)` / `jumpToPage(p)` so the
/// reader is on the destination before the sheet finishes its
/// dismiss animation.
class QuranHubIndexPanel extends StatefulWidget {
  final QuranThemePalette palette;
  final String languageCode;

  const QuranHubIndexPanel({
    super.key,
    required this.palette,
    required this.languageCode,
  });

  @override
  State<QuranHubIndexPanel> createState() => _QuranHubIndexPanelState();
}

class _QuranHubIndexPanelState extends State<QuranHubIndexPanel> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isAr => widget.languageCode == 'ar';

  bool _matches(SurahNamesModel s, String q) {
    if (q.isEmpty) return true;
    final n = q.toLowerCase().trim();
    return s.name.toLowerCase().contains(n) ||
        s.englishName.toLowerCase().contains(n) ||
        s.englishNameTranslation.toLowerCase().contains(n) ||
        s.number.toString() == n;
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return GetBuilder<QuranCtrl>(
      builder: (ctrl) {
        final list = ctrl.surahsList;
        // Defensive: surahsList loads async; show a small skeleton
        // while it's empty so the first sheet open isn't blank.
        if (list.isEmpty) {
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
        final filtered =
            list.where((s) => _matches(s, _query)).toList(growable: false);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: _SurahFilterField(
                controller: _ctrl,
                palette: palette,
                hint: _isAr ? 'ابحث عن سورة' : 'Filter surahs',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1, color: palette.divider, indent: 56, endIndent: 8,
                ),
                itemBuilder: (_, i) => _SurahRow(
                  palette: palette,
                  isAr: _isAr,
                  surah: filtered[i],
                  onTap: () {
                    Navigator.of(context).maybePop();
                    // Defer the jump so the dismiss anim doesn't fight
                    // a same-frame jumpToPage rebuild on the reader.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      QuranLibrary().jumpToSurah(filtered[i].number);
                    });
                  },
                ),
              ),
            ),
            _JuzJumperStrip(
              palette: palette,
              isAr: _isAr,
              onSelect: (juz) {
                Navigator.of(context).maybePop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  QuranLibrary().jumpToJoz(juz);
                });
              },
            ),
          ],
        );
      },
    );
  }
}

class _SurahFilterField extends StatelessWidget {
  final TextEditingController controller;
  final QuranThemePalette palette;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SurahFilterField({
    required this.controller,
    required this.palette,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      cursorColor: palette.accent,
      style: TextStyle(fontSize: 14, color: palette.ink),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Color.alphaBlend(
            palette.accent.withValues(alpha: 0.05), palette.surface),
        hintText: hint,
        hintStyle: TextStyle(color: palette.subInk, fontSize: 13.5),
        prefixIcon: Icon(Icons.search_rounded, size: 18, color: palette.subInk),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.accent, width: 1.5),
        ),
      ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  final QuranThemePalette palette;
  final bool isAr;
  final SurahNamesModel surah;
  final VoidCallback onTap;

  const _SurahRow({
    required this.palette,
    required this.isAr,
    required this.surah,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            // Surah number badge — a small circle with the number.
            Container(
              width: 36, height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                    palette.accent.withValues(alpha: 0.10), palette.surface),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${surah.number}',
                style: TextStyle(
                  fontSize: 13.5,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isAr ? surah.name : surah.englishName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: palette.ink,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      Text(
                        isAr
                            ? '${surah.ayahsNumber} آية'
                            : '${surah.ayahsNumber} ayahs',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: palette.subInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAr
                        ? surah.englishName
                        : surah.englishNameTranslation,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: palette.subInk,
                      height: 1.35,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom strip — 30 juz' chips. Most readers who think in juz'
/// already know which number they want; a strip is faster than
/// digging through a list.
class _JuzJumperStrip extends StatelessWidget {
  final QuranThemePalette palette;
  final bool isAr;
  final ValueChanged<int> onSelect;

  const _JuzJumperStrip({
    required this.palette,
    required this.isAr,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
            palette.accent.withValues(alpha: 0.04), palette.surface),
        border: Border(top: BorderSide(color: palette.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isAr ? 'الانتقال إلى جزء' : 'Jump to juz',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: palette.subInk,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: 30,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final juz = i + 1;
                return GestureDetector(
                  onTap: () => onSelect(juz),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: palette.divider),
                    ),
                    child: Text(
                      '$juz',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
