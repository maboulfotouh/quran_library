part of '/quran.dart';

class _SearchTab extends StatefulWidget {
  final bool isDark;
  final String languageCode;
  final SearchTabStyle? style;
  const _SearchTab(
      {required this.isDark, required this.languageCode, this.style});

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  @override
  void initState() {
    super.initState();
    // على الويب: عطّل تركيز PageView مؤقتًا وأعطِ التركيز لحقل البحث
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kIsWeb) {
        final ctrl = QuranCtrl.instance;
        ctrl.state.quranPageRLFocusNode.canRequestFocus = false;
        if (ctrl.searchFocusNode.canRequestFocus) {
          ctrl.searchFocusNode.requestFocus();
        }
      }
    });
  }

  @override
  void dispose() {
    // عند إغلاق تبويب البحث: أعِد تمكين تركيز PageView للكيبورد على الويب
    if (kIsWeb) {
      final rl = QuranCtrl.instance.state.quranPageRLFocusNode;
      rl.canRequestFocus = true;
      // اطلب التركيز من جديد للسهام اليسار/اليمين
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FocusScope.of(context).requestFocus(rl);
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.style ??
        SearchTabStyle.defaults(isDark: widget.isDark, context: context);
    final Color textColor =
        s.textColor ?? AppColors.getTextColor(widget.isDark);
    // Iqama palette wins inside this surface — accentColor is left
    // as an explicit no-op so future overrides via [style] can be
    // re-attached without changing the structure here.
    // ignore: unused_local_variable
    final accentColor =
        s.accentColor ?? Theme.of(context).colorScheme.primary;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // [iqama fork] Iqama-style search field — white surface,
            // divider hairline unfocused, teal hairline on focus.
            // Leading search icon, hint in tertiary grey.
            TextField(
              controller: QuranCtrl.instance.searchTextController,
              focusNode: QuranCtrl.instance.searchFocusNode,
              autofocus: true,
              onTap: () {
                final ctrl = QuranCtrl.instance;
                ctrl.state.isShowMenu.value = false;
                if (kIsWeb) {
                  ctrl.state.quranPageRLFocusNode.canRequestFocus = false;
                  if (ctrl.searchFocusNode.canRequestFocus) {
                    ctrl.searchFocusNode.requestFocus();
                  }
                }
              },
              onChanged: (txt) {
                final quranCtrl = QuranCtrl.instance;
                if (txt.isEmpty) {
                  quranCtrl.searchResultAyahs.value = [];
                  quranCtrl.searchResultSurahs.value = [];
                  return;
                }
                final ayahResults = QuranLibrary().search(txt);
                quranCtrl.searchResultAyahs.value = [...ayahResults];
                final surahResults = QuranLibrary().surahSearch(txt);
                quranCtrl.searchResultSurahs.value = [...surahResults];
              },
              style: QuranLibrary().cairoStyle.copyWith(
                    fontSize: 15,
                    color: AppColors.textColor,
                    letterSpacing: -0.1,
                  ),
              decoration: InputDecoration(
                fillColor: Colors.white,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 14),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.tealDeep,
                  size: 20,
                ),
                hintText: s.searchHintText ?? 'بحث في القرآن',
                hintStyle: QuranLibrary().cairoStyle.copyWith(
                      color: AppColors.greyLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.divider, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.divider, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Surah chips row
            Obx(() {
              final quranCtrl = QuranCtrl.instance;
              if (quranCtrl.searchResultSurahs.isEmpty) {
                return const SizedBox.shrink();
              }
              return SizedBox(
                height: s.surahChipRowHeight ?? 64,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: quranCtrl.searchResultSurahs.length,
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final search = quranCtrl.searchResultSurahs[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                            (s.surahChipRadius ?? 8).toDouble()),
                        onTap: () async {
                          Navigator.pop(context);
                          quranCtrl.searchResultSurahs.value = [];
                          QuranLibrary().jumpToSurah(search.surahNumber);
                          // إعادة تمكين تركيز PageView بعد إغلاق البحث على الويب
                          if (kIsWeb) {
                            final rl =
                                QuranCtrl.instance.state.quranPageRLFocusNode;
                            rl.canRequestFocus = true;
                            rl.requestFocus();
                          }
                        },
                        // [iqama fork] tealTint pill with tealDeep
                        // label — same shape as a `_Chip` elsewhere
                        // in the app. Hairline border for definition.
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.tealTint,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.teal.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            search.arabicName,
                            style: QuranLibrary().cairoStyle.copyWith(
                                  color: AppColors.tealDeep,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.1,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
            const SizedBox(height: 8),
            // [iqama fork] Ayah results — Iqama card rows.
            // Surah name + page number as a small chip header, ayah
            // rendered below in the package's Quran font. Each card
            // has the same hairline border as the surah list above.
            Expanded(
              child: GetX<QuranCtrl>(
                builder: (quranCtrl) => ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: quranCtrl.searchResultAyahs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final ayah = quranCtrl.searchResultAyahs[i];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pop(context);
                          quranCtrl.searchResultAyahs.value = [];
                          QuranLibrary().jumpToAyah(ayah.page, ayah.ayahUQNumber);
                          if (kIsWeb) {
                            final rl =
                                QuranCtrl.instance.state.quranPageRLFocusNode;
                            rl.canRequestFocus = true;
                            rl.requestFocus();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.dividerSoft),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.tealTint,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      ayah.arabicName ?? '',
                                      style: QuranLibrary().cairoStyle.copyWith(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.tealDeep,
                                            letterSpacing: -0.1,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'صفحة ${ayah.page.toString().convertNumbersAccordingToLang(languageCode: widget.languageCode)}',
                                    style: QuranLibrary().cairoStyle.copyWith(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.grey,
                                          letterSpacing: -0.1,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              IgnorePointer(
                                ignoring: true,
                                child: GetSingleAyah(
                                  surahNumber: ayah.surahNumber!,
                                  ayahNumber: ayah.ayahNumber,
                                  isBold: false,
                                  fontSize: 22,
                                  textColor: textColor,
                                  isDark: widget.isDark,
                                  pageIndex: ayah.page,
                                  enabledTajweed:
                                      quranCtrl.state.isTajweedEnabled.value,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
