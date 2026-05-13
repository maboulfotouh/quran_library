part of '/quran.dart';

class _IndexTab extends StatelessWidget {
  final bool isDark;
  final String languageCode;
  final IndexTabStyle style;
  const _IndexTab(
      {required this.isDark, required this.languageCode, required this.style});

  @override
  Widget build(BuildContext context) {
    final jozzList = QuranLibrary.allJoz;
    final hizbList = QuranLibrary.allHizb;
    final surahs = QuranLibrary.getAllSurahs(isArabic: false);

    // accentColor + textColor are no longer used at this level —
    // the inner tab pill is hardcoded to the Iqama palette and the
    // child lists pull their own text colors. Kept around for any
    // future host-supplied overrides via [style].
    // ignore: unused_local_variable
    final accentColor =
        style.accentColor ?? Theme.of(context).colorScheme.primary;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // [iqama fork] Inner segmented pill mirrors the outer
          // sheet's tabs (tealTint track, teal selected pill).
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.tealTint,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.dividerSoft),
            ),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(9),
              ),
              indicatorPadding:
                  style.indicatorPadding ?? const EdgeInsets.all(3),
              dividerColor: Colors.transparent,
              padding: EdgeInsets.zero,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.tealDeep,
              indicatorColor: accentColor,
              indicatorWeight: .5,
              labelStyle: QuranLibrary().cairoStyle.copyWith(
                  fontSize: 13.5, fontWeight: FontWeight.w700,
                  height: 1.3, letterSpacing: -0.1),
              unselectedLabelStyle: QuranLibrary().cairoStyle.copyWith(
                  fontSize: 13.5, fontWeight: FontWeight.w600,
                  letterSpacing: -0.1),
              tabs: [
                Tab(text: style.tabSurahsLabel ?? 'السور'),
                Tab(text: style.tabJozzLabel ?? 'الأجزاء'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _SurahsList(
                    isDark: isDark,
                    languageCode: languageCode,
                    surahs: surahs,
                    style: style),
                _JozzList(
                    isDark: isDark,
                    jozzList: jozzList,
                    hizbList: hizbList,
                    style: style),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _SurahsList extends StatelessWidget {
  final bool isDark;
  final String languageCode;
  final List<String> surahs;
  final IndexTabStyle style;
  const _SurahsList(
      {required this.isDark,
      required this.languageCode,
      required this.surahs,
      required this.style});

  @override
  Widget build(BuildContext context) {
    // احسب السورة الحالية من الكنترولر
    int? currentIndex;
    try {
      final ctrl = QuranCtrl.instance;
      final currentPage = ctrl.state.currentPageNumber.value;
      final surahNumber =
          ctrl.getCurrentSurahByPageNumber(currentPage).surahNumber;
      currentIndex = (surahNumber - 1).clamp(0, surahs.length - 1);
    } catch (_) {}

    // استخدم ScrollController للتمرير بالاعتماد على ارتفاع تقريبي للعنصر
    final scrollCtrl = ScrollController();
    const double itemHeight = 68.0; // ارتفاع تقديري لكل صف
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentIndex != null && scrollCtrl.hasClients) {
        final max = scrollCtrl.position.maxScrollExtent;
        final desired = (currentIndex * itemHeight) - (itemHeight * 1.5);
        final target = desired.clamp(0.0, max);
        scrollCtrl.jumpTo(target);
      }
    });

    final Color textColor = style.textColor ?? AppColors.getTextColor(isDark);
    // [iqama fork] Iqama card-row: white tile, hairline divider,
    // circular tealTint badge with the surah number, plain Arabic
    // surah name (the calligraphic font reads as decoration, not
    // a label — clearer to ship the Cairo name only here).
    return ListView.builder(
      controller: scrollCtrl,
      itemCount: surahs.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        final bool isCurrent = (currentIndex == index);
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.pop(context);
              QuranLibrary().jumpToSurah(index + 1);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrent ? AppColors.tealTint : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrent ? AppColors.teal : AppColors.dividerSoft,
                  width: isCurrent ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Number badge — circle, tealTint background,
                  // tealDeep numeral. Becomes teal/white when this
                  // is the current surah so the eye lands on it.
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isCurrent ? AppColors.teal : AppColors.tealTint,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}'.convertNumbersAccordingToLang(
                          languageCode: languageCode),
                      style: QuranLibrary().cairoStyle.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isCurrent ? Colors.white : AppColors.tealDeep,
                            letterSpacing: -0.1,
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
                          surahs[index],
                          style: QuranLibrary().cairoStyle.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                                letterSpacing: -0.15,
                                height: 1.2,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ' surah${(index + 1).toString().padLeft(3, '0')} ',
                          style: TextStyle(
                            color: AppColors.tealDeep,
                            fontFamily: 'surah-name-v4',
                            fontSize: 22,
                            package: 'quran_library',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: isCurrent
                        ? AppColors.tealDeep
                        : AppColors.greyLight,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _JozzList extends StatelessWidget {
  final bool isDark;
  final List<String> jozzList;
  final List<String> hizbList;
  final IndexTabStyle style;
  const _JozzList(
      {required this.isDark,
      required this.jozzList,
      required this.hizbList,
      required this.style});

  @override
  Widget build(BuildContext context) {
    // احسب الجزء الحالي من الكنترولر
    int? currentJozzIndex;
    try {
      final ctrl = QuranCtrl.instance;
      final currentPage = ctrl.state.currentPageNumber.value;
      final juz = ctrl.getJuzByPage(currentPage).juz; // 1..30
      currentJozzIndex = (juz - 1).clamp(0, jozzList.length - 1);
    } catch (_) {}

    // ScrollController للتمرير إلى الجزء الحالي باستخدام ارتفاع تقريبي
    final jozzScrollCtrl = ScrollController();
    const double tileHeight = 60.0; // ارتفاع تقديري لكل عنصر جزء
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentJozzIndex != null && jozzScrollCtrl.hasClients) {
        final max = jozzScrollCtrl.position.maxScrollExtent;
        final desired = (currentJozzIndex * tileHeight) - (tileHeight * 1.0);
        final target = desired.clamp(0.0, max);
        jozzScrollCtrl.jumpTo(target);
      }
    });

    final Color textColor = style.textColor ?? AppColors.getTextColor(isDark);
    // [iqama fork] Juz rows are Iqama-style cards. Current juz gets
    // a tealTint background + teal border so the user can find their
    // spot quickly. ExpansionTile reveals the two hizbs inside.
    return ListView.builder(
      controller: jozzScrollCtrl,
      itemCount: jozzList.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, jozzIndex) {
        final isCurrent = currentJozzIndex == jozzIndex;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: isCurrent ? AppColors.tealTint : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrent ? AppColors.teal : AppColors.dividerSoft,
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: Theme(
            // Strip ExpansionTile's default top/bottom divider lines
            // since they fight with our card border.
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: ExpansionTile(
              initiallyExpanded: isCurrent,
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              iconColor: AppColors.tealDeep,
              collapsedIconColor: AppColors.greyLight,
              leading: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isCurrent ? AppColors.teal : AppColors.tealTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bookmark_rounded,
                  size: 18,
                  color: isCurrent ? Colors.white : AppColors.tealDeep,
                ),
              ),
              title: Text(
                jozzList[jozzIndex],
                style: QuranLibrary().cairoStyle.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      letterSpacing: -0.1,
                    ),
              ),
              children: List.generate(2, (index) {
                final hizbIndex = (index == 0 && jozzIndex == 0)
                    ? 0
                    : (jozzIndex * 2 + index);
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.pop(context);
                      QuranLibrary().jumpToHizb(hizbIndex + 1);
                    },
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.dividerSoft),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.subdirectory_arrow_left_rounded,
                            size: 14,
                            color: AppColors.greyLight,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hizbList[hizbIndex],
                              style: QuranLibrary().cairoStyle.copyWith(
                                    fontSize: 13.5,
                                    color: textColor,
                                    letterSpacing: -0.1,
                                  ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: AppColors.greyLight,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
