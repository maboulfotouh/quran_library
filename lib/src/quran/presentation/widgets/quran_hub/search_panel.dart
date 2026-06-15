part of '/quran.dart';

/// Search tab inside the [QuranHubSheet] — both ayah full-text and
/// surah-name search in one input. Surah results sit at the top
/// (small, instant nav) so a user who just wanted to jump to
/// Al-Baqarah doesn't have to scroll past 60 ayah results to
/// reach the surah row.
///
/// Debounced 220ms so the search APIs aren't hammered with every
/// keystroke. Tap any result → close sheet + jump to that ayah
/// (or surah, which is just "jump to surah's first page").
class QuranHubSearchPanel extends StatefulWidget {
  final QuranThemePalette palette;
  final String languageCode;

  const QuranHubSearchPanel({
    super.key,
    required this.palette,
    required this.languageCode,
  });

  @override
  State<QuranHubSearchPanel> createState() => _QuranHubSearchPanelState();
}

class _QuranHubSearchPanelState extends State<QuranHubSearchPanel> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<AyahModel> _ayahHits = const [];
  List<SurahModel> _surahHits = const [];
  String _query = '';

  bool get _isAr => widget.languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    // Auto-focus so the keyboard is up and the cursor blinks the
    // moment the user lands on the Search tab. Saves a tap.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      final q = value.trim();
      if (!mounted) return;
      if (q.isEmpty) {
        setState(() {
          _query = '';
          _ayahHits = const [];
          _surahHits = const [];
        });
        return;
      }
      final ayahs  = QuranLibrary().search(q);
      final surahs = QuranLibrary().surahSearch(q);
      setState(() {
        _query = q;
        _ayahHits = ayahs;
        _surahHits = surahs;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            onChanged: _onChanged,
            cursorColor: palette.accent,
            style: TextStyle(fontSize: 14, color: palette.ink),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Color.alphaBlend(
                  palette.accent.withValues(alpha: 0.05), palette.surface),
              hintText:
                  _isAr ? 'ابحث في الآيات أو السور' : 'Search ayahs or surahs',
              hintStyle: TextStyle(color: palette.subInk, fontSize: 13.5),
              prefixIcon:
                  Icon(Icons.search_rounded, size: 18, color: palette.subInk),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: palette.subInk),
                      onPressed: () {
                        _ctrl.clear();
                        _onChanged('');
                      },
                    )
                  : null,
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
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    final palette = widget.palette;
    if (_query.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _isAr
                ? 'ابدأ بكتابة كلمة من آية أو اسم سورة'
                : 'Type a word from an ayah or a surah name',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.subInk, fontSize: 13.5, height: 1.5),
          ),
        ),
      );
    }
    if (_ayahHits.isEmpty && _surahHits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _isAr ? 'لا توجد نتائج' : 'No matches',
            style: TextStyle(color: palette.subInk, fontSize: 13.5),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      children: [
        if (_surahHits.isNotEmpty) ...[
          _SectionHeader(
            palette: palette,
            label: _isAr ? 'السور' : 'Surahs',
            count: _surahHits.length,
          ),
          for (final s in _surahHits) _SurahHit(palette: palette, surah: s, isAr: _isAr),
          const SizedBox(height: 12),
        ],
        if (_ayahHits.isNotEmpty) ...[
          _SectionHeader(
            palette: palette,
            label: _isAr ? 'الآيات' : 'Ayahs',
            count: _ayahHits.length,
          ),
          for (final a in _ayahHits.take(80))
            _AyahHit(palette: palette, ayah: a, isAr: _isAr),
          if (_ayahHits.length > 80)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(
                _isAr
                    ? 'تم عرض أول ٨٠ نتيجة'
                    : 'Showing the first 80 results',
                style: TextStyle(color: palette.subInk, fontSize: 11.5),
              ),
            ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final QuranThemePalette palette;
  final String label;
  final int count;
  const _SectionHeader(
      {required this.palette, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      child: Row(
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: palette.subInk,
                letterSpacing: 1.4,
              )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                  palette.accent.withValues(alpha: 0.10), palette.surface),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: palette.accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ),
        ],
      ),
    );
  }
}

class _SurahHit extends StatelessWidget {
  final QuranThemePalette palette;
  final SurahModel surah;
  final bool isAr;
  const _SurahHit({
    required this.palette,
    required this.surah,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).maybePop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          QuranLibrary().jumpToSurah(surah.surahNumber);
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                    palette.accent.withValues(alpha: 0.10), palette.surface),
                shape: BoxShape.circle,
              ),
              child: Text('${surah.surahNumber}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: palette.accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isAr ? surah.arabicName : surah.englishName,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: palette.subInk),
          ],
        ),
      ),
    );
  }
}

class _AyahHit extends StatelessWidget {
  final QuranThemePalette palette;
  final AyahModel ayah;
  final bool isAr;
  const _AyahHit({
    required this.palette,
    required this.ayah,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).maybePop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          QuranLibrary().jumpToAyah(ayah.page, ayah.ayahUQNumber);
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isAr
                      ? 'الآية ${ayah.ayahNumber} · صفحة ${ayah.page}'
                      : 'Ayah ${ayah.ayahNumber} · Page ${ayah.page}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: palette.subInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              ayah.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                color: palette.ink,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
