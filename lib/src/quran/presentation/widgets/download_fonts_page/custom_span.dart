part of '/quran.dart';

TextSpan _qpcV4SpanSegment({
  required BuildContext context,
  required int pageIndex,
  required bool isSelected,
  required bool showAyahBookmarkedIcon,
  required double fontSize,
  required int ayahUQNum,
  required int ayahNumber,
  required WordRef wordRef,
  required bool isWordKhilaf,
  required String glyphs,
  required bool showAyahNumber,
  _LongPressStartDetailsFunction? onLongPressStart,
  required Color? textColor,
  required Color? ayahIconColor,
  required List<int> bookmarksAyahs,
  required List<int> ayahBookmarked,
  required List<BookmarkModel> allBookmarksList,
  Color? bookmarksColor,
  Color? Function(AyahModel)? customBookmarksColor,
  Color? ayahSelectedBackgroundColor,
  bool Function(AyahModel ayah)? isAyahBookmarked,
  required bool isFontsLocal,
  required String fontsName,
  String? fontFamilyOverride,
  String? fontPackageOverride,
  bool usePaintColoring = true,
  required bool isDark,
  VoidCallback? onPagePress,
  // [iqama fork] Pre-computed per-page styles. When the caller is
  // batching a whole page's spans it computes these ONCE up front
  // and reuses them for every word — saves a TextStyle allocation,
  // a `getFontPath` map lookup, a `Theme.of(context)` walk, and a
  // `withTajweed`/`isTenRecitations` field read per word. On a page
  // with ~250 words that's the difference between a smooth swipe
  // and a 200 ms hitch on mid-end devices.
  String? precomputedFontFamily,
  TextStyle? precomputedBaseStyle,
  TextStyle? precomputedAyahNumberStyle,
  bool? precomputedWithTajweed,
  bool? precomputedIsTenRecitations,
  // [iqama fork] Optional shared recognizer for ALL the words of a
  // single ayah. Word selection mode needs per-word recognizers
  // (each one's `setSelectedWord(wordRef)` differs), so this is
  // only honoured when word selection is disabled. When honoured,
  // the per-word `TapLongPressRecognizer` allocation goes away —
  // a typical Mushaf page drops from ~250 recognizers down to ~30
  // (one per ayah), which is a massive reduction in gesture-arena
  // pressure during swipes on a mid-range tablet.
  GestureRecognizer? sharedAyahRecognizer,
}) {
  final quranCtrl = QuranCtrl.instance;
  final wordInfoCtrl = WordInfoCtrl.instance;
  final AyahModel ayahModel = quranCtrl.getAyahByUq(ayahUQNum);

  final withTajweed =
      precomputedWithTajweed ?? quranCtrl.state.isTajweedEnabled.value;
  final isTenRecitations =
      precomputedIsTenRecitations ?? wordInfoCtrl.isTenRecitations;
  final bool forceRed = isWordKhilaf && !withTajweed && isTenRecitations;

  // اختيار الخط: كلمات الخلاف تستخدم خط CPAL أحمر بدلاً من foreground Paint
  final String fontFamily;
  if (forceRed) {
    // forceRed always wins — the red font is page-specific anyway.
    fontFamily = quranCtrl.getRedFontPath(pageIndex);
  } else if (fontFamilyOverride != null) {
    fontFamily = fontFamilyOverride;
  } else if (isFontsLocal) {
    fontFamily = fontsName;
  } else if (precomputedFontFamily != null) {
    fontFamily = precomputedFontFamily;
  } else {
    fontFamily = quranCtrl.getFontPath(pageIndex, isDark: isDark);
  }

  // Re-use the precomputed style when it matches what we would have
  // built (same fontFamily) — the `forceRed` and override branches
  // need a per-word style.
  final TextStyle baseTextStyle;
  if (!forceRed &&
      precomputedBaseStyle != null &&
      precomputedBaseStyle.fontFamily == fontFamily &&
      precomputedBaseStyle.fontSize == fontSize) {
    baseTextStyle = precomputedBaseStyle;
  } else {
    baseTextStyle = TextStyle(
      fontFamily: fontFamily,
      package: fontPackageOverride,
      fontSize: fontSize,
      height: 2,
      // wordSpacing: 50,
      color: textColor ?? AppColors.getTextColor(isDark),
    );
  }

  InlineSpan? tail;
  final hasBookmark = isAyahBookmarked != null
      ? isAyahBookmarked(ayahModel)
      : (ayahBookmarked.contains(ayahUQNum) ||
          bookmarksAyahs.contains(ayahUQNum));
  if (showAyahNumber) {
    tail = hasBookmark && showAyahBookmarkedIcon && !kIsWeb
        ? WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: quranCtrl.isQpcV4Enabled
                  ? const EdgeInsets.symmetric(horizontal: 4.0)
                  : const EdgeInsets.only(right: 4.0, left: 4.0, bottom: 16.0),
              child: SvgPicture.asset(
                AssetsPath.assets.ayahBookmarked,
                height: UiHelper.currentOrientation(30.0.h, 130.0.h, context),
                width: UiHelper.currentOrientation(30.0.w, 130.0.w, context),
              ),
            ),
          )
        : TextSpan(
            text: usePaintColoring
                ? '${'$ayahNumber'.convertEnglishNumbersToArabic(ayahNumber.toString())}\u202F\u202F'
                : '\u202F${'$ayahNumber'.convertEnglishNumbersToArabic(ayahNumber.toString())}\u202F',
            // Re-use the page-level ayah-number style when one was
            // supplied; otherwise build the per-word style as before.
            style: precomputedAyahNumberStyle ??
                TextStyle(
                  fontFamily: 'ayahNumber',
                  fontSize: usePaintColoring ? (fontSize + 5) : (fontSize + 5),
                  height: 1.5,
                  package: 'quran_library',
                  color: ayahIconColor ?? Theme.of(context).colorScheme.primary,
                ),
            recognizer: LongPressGestureRecognizer(
                duration: const Duration(milliseconds: 500))
              ..onLongPressStart = onLongPressStart,
          );
  }

  final GestureRecognizer recognizer;
  if (!wordInfoCtrl.isWordSelectionEnabled) {
    // [iqama fork] If the caller already built one recognizer for
    // the whole ayah, reuse it across every word — saves the
    // per-word TapLongPressRecognizer allocation AND keeps the
    // gesture arena from tracking 250 listeners per page on
    // mid-range tablets.
    if (sharedAyahRecognizer != null) {
      recognizer = sharedAyahRecognizer;
    } else {
      // تحديد الكلمة معطّل: الضغط القصير لا يفعل شيئاً، الضغط المطوّل يفتح قائمة الآية
      recognizer = TapLongPressRecognizer(
        shortHoldDuration: const Duration(milliseconds: 150),
        longHoldDuration: const Duration(milliseconds: 500),
      )
        ..onQuickTapCallback = onPagePress
        ..onShortHoldStartCallback = () {
          // فارغ عمداً — لإبقاء الحدث حياً حتى يصل للضغط المطوّل
        }
        ..onShortHoldCompleteCallback = null
        ..onLongHoldStartCallback = (details) {
          onLongPressStart?.call(details);
        };
    }
  } else {
    recognizer = TapLongPressRecognizer(
      shortHoldDuration: const Duration(milliseconds: 150),
      longHoldDuration: const Duration(milliseconds: 500),
    )
      ..onQuickTapCallback = onPagePress
      ..onShortHoldStartCallback = () {
        wordInfoCtrl.setSelectedWord(wordRef);
      }
      ..onShortHoldCompleteCallback = () {
        () async {
          if (!context.mounted) return;
          await showWordInfoBottomSheet(
              context: context, ref: wordRef, isDark: isDark);
          if (!context.mounted) return;
          wordInfoCtrl.clearSelectedWord();
        }();
      }
      ..onLongHoldStartCallback = (details) {
        wordInfoCtrl.clearSelectedWord();
        onLongPressStart?.call(details);
      };
  }

  return TextSpan(
    children: <InlineSpan>[
      TextSpan(
        text: glyphs,
        style: baseTextStyle,
        recognizer: recognizer,
      ),
      if (tail != null) tail,
    ],
  );
}

typedef _LongPressStartDetailsFunction = void Function(LongPressStartDetails)?;
