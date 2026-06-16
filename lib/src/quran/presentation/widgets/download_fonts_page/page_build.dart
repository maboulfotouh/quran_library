part of '/quran.dart';

/// [iqama fork] Page-already-fully-rendered cache.
///
/// Once a page has fully rendered once during this isolate's lifetime,
/// every subsequent mount skips the deferred-render placeholder and
/// renders the full widget tree synchronously. This matters because
/// `_KeepAlive` only protects pages that stay inside the PageView's
/// cacheExtent — a page that drifts FAR out of cache (e.g. user
/// jumps from page 5 to page 300) gets disposed, and when they come
/// back the State would otherwise be fresh and force the placeholder
/// again. Keying the "fully rendered" memory by pageIndex keeps the
/// memo across that disposal.
final Set<int> _pageBuildEverFullyRendered = <int>{};

class PageBuild extends StatefulWidget {
  const PageBuild({
    super.key,
    required this.pageIndex,
    required this.surahNumber,
    this.surahFilterNumber,
    required this.bannerStyle,
    required this.isDark,
    required this.surahNameStyle,
    required this.onSurahBannerPress,
    required this.basmalaStyle,
    required this.textColor,
    required this.bookmarks,
    required this.onAyahLongPress,
    required this.bookmarkList,
    required this.ayahIconColor,
    required this.showAyahBookmarkedIcon,
    required this.bookmarksAyahs,
    required this.bookmarksColor,
    this.customBookmarksColor,
    required this.ayahSelectedBackgroundColor,
    required this.isFontsLocal,
    required this.fontsName,
    required this.ayahBookmarked,
    this.isAyahBookmarked,
    required this.context,
    required this.quranCtrl,
    this.onPagePress,
  });

  final int pageIndex;
  final int? surahNumber;
  final int? surahFilterNumber;
  final BannerStyle? bannerStyle;
  final bool isDark;
  final SurahNameStyle? surahNameStyle;
  final Function(SurahNamesModel surah)? onSurahBannerPress;
  final BasmalaStyle? basmalaStyle;
  final Color? textColor;
  final Map<int, List<BookmarkModel>> bookmarks;
  final Function(LongPressStartDetails details, AyahModel ayah)?
      onAyahLongPress;
  final List? bookmarkList;
  final Color? ayahIconColor;
  final bool showAyahBookmarkedIcon;
  final List<int> bookmarksAyahs;
  final Color? bookmarksColor;
  final Color? Function(AyahModel)? customBookmarksColor;
  final Color? ayahSelectedBackgroundColor;
  final bool? isFontsLocal;
  final String? fontsName;
  final List<int> ayahBookmarked;
  final bool Function(AyahModel ayah)? isAyahBookmarked;
  final BuildContext context;
  final QuranCtrl quranCtrl;
  final VoidCallback? onPagePress;

  @override
  State<PageBuild> createState() => _PageBuildState();
}

class _PageBuildState extends State<PageBuild> {
  /// [iqama fork] Whether this page's full widget tree should be
  /// built right now. The whole point of this flag is to skip the
  /// heavy `FittedBox + Column + 15 × QpcV4RichTextLine` mount cost
  /// during the swipe gesture that brought us into view, and run it
  /// only once the scheduler is genuinely idle (i.e. the swipe has
  /// settled). See [initState] for the scheduling.
  bool _fullyMounted = false;

  @override
  void initState() {
    super.initState();
    // If this pageIndex has already rendered fully in a previous
    // mount this session, skip the placeholder entirely — re-mounting
    // the same page after it scrolled FAR out of cache should not
    // re-introduce the loading flash.
    if (_pageBuildEverFullyRendered.contains(widget.pageIndex)) {
      _fullyMounted = true;
      return;
    }
    // Schedule the full build at `Priority.idle` (= 100, lower than
    // `Priority.animation` = 150 and `Priority.touch` = 200). While
    // the user is mid-swipe, every frame is animation/touch work, so
    // this task waits. The instant the swipe settles and the
    // scheduler runs out of higher-priority work, the task fires,
    // we `setState`, and the page rebuilds with its real content.
    //
    // Net effect: the swipe gesture animates with a cheap
    // `SizedBox.expand` placeholder; the expensive `FittedBox +
    // Column + RichText` tree only enters the frame budget once the
    // user has actually arrived. Subsequent visits to the same
    // page short-circuit via the static `_pageBuildEverFullyRendered`
    // set above.
    SchedulerBinding.instance.scheduleTask<void>(() {
      if (!mounted) return;
      _pageBuildEverFullyRendered.add(widget.pageIndex);
      setState(() => _fullyMounted = true);
    }, Priority.idle);
  }

  @override
  Widget build(BuildContext context) {
    final quranCtrl = widget.quranCtrl;
    final pageIndex = widget.pageIndex;
    final surahFilterNumber = widget.surahFilterNumber;
    final bannerStyle = widget.bannerStyle;
    final isDark = widget.isDark;
    final surahNameStyle = widget.surahNameStyle;
    final onSurahBannerPress = widget.onSurahBannerPress;
    final basmalaStyle = widget.basmalaStyle;
    final textColor = widget.textColor;
    final bookmarks = widget.bookmarks;
    final onAyahLongPress = widget.onAyahLongPress;
    final bookmarkList = widget.bookmarkList;
    final ayahIconColor = widget.ayahIconColor;
    final showAyahBookmarkedIcon = widget.showAyahBookmarkedIcon;
    final bookmarksAyahs = widget.bookmarksAyahs;
    final bookmarksColor = widget.bookmarksColor;
    final customBookmarksColor = widget.customBookmarksColor;
    final ayahSelectedBackgroundColor = widget.ayahSelectedBackgroundColor;
    final isFontsLocal = widget.isFontsLocal;
    final fontsName = widget.fontsName;
    final ayahBookmarked = widget.ayahBookmarked;
    final isAyahBookmarked = widget.isAyahBookmarked;
    final onPagePress = widget.onPagePress;

    if (!quranCtrl.isQpcLayoutEnabled) {
      return const SizedBox.shrink();
    }

    // التحميل الكسول: تأكد أن خط هذه الصفحة جاهز
    final int pageNumber = pageIndex + 1;
    if (!QuranFontsService.isPageReady(pageNumber)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        QuranFontsService.ensurePagesLoaded(pageNumber, radius: 10).then((_) {
          quranCtrl.update();
          quranCtrl.update(['_pageViewBuild']);
        });
      });
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    final blocks = quranCtrl.getQpcLayoutBlocksForPageSync(pageNumber);
    if (blocks.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    // [iqama fork] Deferred-render placeholder. Takes the full
    // page slot so the PageView's layout doesn't see a collapsed
    // child during the swipe; renders effectively for free.
    if (!_fullyMounted) {
      return const SizedBox.expand();
    }

    return RepaintBoundary(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: blocks.map((b) {
            // عند عرض سورة واحدة: نتجاهل الهيدر/البسملة من الـ layout ونتركها للـ SurahPage.
            if (surahFilterNumber != null &&
                (b is QpcV4SurahHeaderBlock || b is QpcV4BasmallahBlock)) {
              return const SizedBox.shrink();
            }

            if (b is QpcV4SurahHeaderBlock) {
              return SurahHeaderWidget(
                b.surahNumber,
                bannerStyle: bannerStyle ??
                    BannerStyle.downloadFonts(isDark: isDark, context: context),
                surahNameStyle: surahNameStyle ??
                    SurahNameStyle.downloadFonts(
                        isDark: isDark, context: context),
                onSurahBannerPress: onSurahBannerPress,
                isDark: isDark,
              );
            }

            if (b is QpcV4BasmallahBlock) {
              return BasmallahWidget(
                surahNumber: b.surahNumber,
                basmalaStyle: basmalaStyle ??
                    BasmalaStyle.downloadFonts(
                        isDark: isDark, context: context),
              );
            }

            if (b is QpcV4AyahLineBlock) {
              final filteredSegments = (surahFilterNumber == null)
                  ? b.segments
                  : b.segments
                      .where((s) => s.surahNumber == surahFilterNumber)
                      .toList(growable: false);

              if (filteredSegments.isEmpty) {
                return const SizedBox.shrink();
              }

              // [iqama fork] Per-line RepaintBoundary removed. With
              // 15 lines per page × ~9 keep-alive pages, the prior
              // setup spun up ~135 leaf layers — each one a paint
              // layer the compositor has to track, allocate GPU
              // memory for, and walk on every frame. For typical
              // reading no single line changes in isolation (no
              // partial-paint scenarios that would benefit from a
              // per-line layer), so the boundaries cost without
              // earning anything. The page-level RepaintBoundary in
              // `_ItemBuilderWidget` still gives us the
              // page-as-a-unit layer caching we actually rely on.
              return QpcV4RichTextLine(
                pageIndex: pageIndex,
                textColor: textColor,
                isDark: isDark,
                bookmarks: bookmarks,
                onAyahLongPress: onAyahLongPress,
                bookmarkList: bookmarkList,
                ayahIconColor: ayahIconColor,
                showAyahBookmarkedIcon: showAyahBookmarkedIcon,
                bookmarksAyahs: bookmarksAyahs,
                bookmarksColor: bookmarksColor,
                customBookmarksColor: customBookmarksColor,
                ayahSelectedBackgroundColor: ayahSelectedBackgroundColor,
                context: context,
                quranCtrl: quranCtrl,
                segments: filteredSegments,
                isFontsLocal: isFontsLocal ?? false,
                fontsName: fontsName ?? '',
                fontFamilyOverride: null,
                fontPackageOverride: null,
                usePaintColoring: true,
                ayahBookmarked: ayahBookmarked,
                isAyahBookmarked: isAyahBookmarked,
                isCentered: b.isCentered,
                onPagePress: onPagePress,
              );
            }

            return const SizedBox.shrink();
          }).toList(),
        ),
      ),
    );
  }
}
