part of '/quran.dart';

/// ويدجت لعرض محتوى السورة المخصصة مع المعلومات المطلوبة
/// Widget for displaying custom surah content with required information
class TopAndBottomWidget extends StatelessWidget {
  final int pageIndex;
  final bool isRight;
  final bool? isSurah;
  final int? surahNumber;
  final String? languageCode;
  final Widget child;

  TopAndBottomWidget({
    super.key,
    required this.pageIndex,
    required this.isRight,
    required this.child,
    this.languageCode,
    this.isSurah = false,
    this.surahNumber,
  });

  final surahCtrl = SurahCtrl.instance;
  final quranCtrl = QuranCtrl.instance;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topBottomStyle = TopBottomTheme.of(context)?.style ??
        TopBottomQuranStyle.defaults(isDark: isDark, context: context);
    final isMobileLargeOrDesktop = Responsive.isMobile(context) ||
        Responsive.isMobileLarge(context) ||
        Responsive.isDesktop(context);
    // [iqama fork] Optional host-supplied per-page action (e.g.
    // "mark page as read"). Rendered just above the bottom strip
    // so the natural reading flow lands on it as the user finishes
    // a page. Sized to ~44px so the bottom indicators stay legible.
    final Widget? pageAction = topBottomStyle.pageActionBuilder?.call(
      context, pageIndex,
    );
    return UiHelper.currentOrientation(
      // شرح: التخطيط العمودي (Portrait)
      // Explanation: Portrait layout
      Stack(
        children: [
          // شرح: العنوان العلوي
          // Explanation: Top title
          Align(
            alignment: Alignment.topCenter,
            child: BuildTopSection(
              isRight: isRight,
              languageCode: languageCode,
              pageIndex: pageIndex,
              isSurah: isSurah!,
              surahNumber: surahNumber,
            ),
          ),

          // شرح: المحتوى الرئيسي
          // Explanation: Main content
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: child,
            ),
          ),

          // شرح: القسم السفلي
          // Explanation: Bottom section
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pageAction != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: pageAction,
                  ),
                BuildBottomSection(
                    pageIndex: pageIndex,
                    isRight: isRight,
                    languageCode: languageCode!),
              ],
            ),
          ),
        ],
      ),

      // شرح: التخطيط الأفقي (Landscape)
      // Explanation: Landscape layout
      isMobileLargeOrDesktop
          ? LayoutBuilder(
              builder: (context, constraints) {
                final bounded = constraints.maxHeight.isFinite;
                return Column(
                  children: [
                    BuildTopSection(
                      isRight: isRight,
                      languageCode: languageCode,
                      pageIndex: pageIndex,
                      isSurah: isSurah!,
                      surahNumber: surahNumber,
                    ),
                    if (bounded) Flexible(child: child) else child,
                    if (pageAction != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                        child: pageAction,
                      ),
                    BuildBottomSection(
                        pageIndex: pageIndex,
                        isRight: isRight,
                        languageCode: languageCode!),
                  ],
                );
              },
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  BuildTopSection(
                    isRight: isRight,
                    languageCode: languageCode,
                    pageIndex: pageIndex,
                    isSurah: isSurah!,
                    surahNumber: surahNumber,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: child,
                  ),
                  if (pageAction != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                      child: pageAction,
                    ),
                  BuildBottomSection(
                      pageIndex: pageIndex,
                      isRight: isRight,
                      languageCode: languageCode!),
                ],
              ),
            ),
      context,
    );
  }
}
