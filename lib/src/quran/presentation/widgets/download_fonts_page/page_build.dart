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
  /// [iqama fork] How many blocks of this page have been promoted
  /// from "placeholder" to "rendered" so far. The build loop
  /// promotes ONE block per frame (see [_runIncrementalBuild]),
  /// yielding at `SchedulerBinding.endOfFrame` between each, so a
  /// user-initiated swipe that lands between two promotions is
  /// delayed at most ~one block's worth of work (~5-7 ms for a
  /// single `QpcV4RichTextLine`'s text-shaping). The prior Q13
  /// atomic deferred-render scheduled the WHOLE build in one
  /// uninterruptible `Priority.idle` task, which meant a second
  /// swipe arriving mid-build had to wait the full ~100 ms — the
  /// "stuck second swipe" symptom.
  ///
  /// Sentinel value -1 = the page is fully rendered (memoised in
  /// the static `_pageBuildEverFullyRendered` set below).
  int _builtBlocks = 0;

  @override
  void initState() {
    super.initState();
    if (_pageBuildEverFullyRendered.contains(widget.pageIndex)) {
      _builtBlocks = -1;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // [iqama fork — Q14 polish] If we're the currently-focused
      // page AND there's no active scroll (i.e. cold-open path
      // where the user has just arrived at their landing page and
      // hasn't started swiping yet), render eagerly: one paint that
      // shows the full page right away. The placeholder + line-by-
      // line fill-in is the wrong UX here — the user opened the
      // reader expecting to see content, not to watch it stream in.
      //
      // Pages mounted in the PageView's keep-alive cache (NOT
      // focused) OR mounted mid-swipe (scroll active) still go
      // through the incremental path. That way only the page the
      // user is staring at pays the eager-render cost; off-screen
      // cache pages don't all compete for the frame budget on
      // open.
      final scrollable = Scrollable.maybeOf(context);
      final isScrolling = scrollable != null &&
          Scrollable.recommendDeferredLoadingForContext(context);
      final isFocused = widget.quranCtrl.state.currentPageNumber.value ==
          widget.pageIndex + 1;
      if (isFocused && !isScrolling) {
        _pageBuildEverFullyRendered.add(widget.pageIndex);
        setState(() => _builtBlocks = -1);
        return;
      }
      _runIncrementalBuild();
    });
  }

  /// [iqama fork] One block per frame. Between blocks we
  /// `await SchedulerBinding.instance.endOfFrame`, which resolves
  /// at the *end* of whichever frame is currently running — so the
  /// next promotion lands on the next frame, naturally interleaving
  /// with any animation or gesture work the scheduler is doing.
  ///
  /// Before each promotion we also wait for the scrollable to
  /// settle (`Scrollable.recommendDeferredLoadingForContext`
  /// returns true while the scroll velocity is above the fling
  /// threshold). That means a fast swipe pauses the build
  /// entirely; the moment the snap completes, the next block
  /// promotes.
  Future<void> _runIncrementalBuild() async {
    // [iqama fork — Q14 fix] Wait until the blocks for this page
    // are actually populated before kicking off promotions.
    //
    // On a cold open the initial pages mount BEFORE Q5's eager
    // prewarm has had time to fill `_qpcV4BlocksByPage`, so
    // `getQpcLayoutBlocksForPageSync` returns the empty list
    // sentinel — meanwhile triggering an async prewarm that
    // eventually fires `update(['qpc_page_$pageIndex'])`.
    // The previous version of this loop bailed on `total == 0`,
    // which left `_builtBlocks` stuck at 0 forever: when the later
    // `update` rebuilt PageBuild, the outer build saw non-empty
    // blocks but `_builtBlocks == 0` still returned
    // `SizedBox.expand()`. That's the "first pages blank" symptom.
    //
    // Poll instead. The check is O(1) (a Map lookup), so a handful
    // of extra empty frames while we wait for prewarm cost
    // essentially nothing; once blocks arrive the loop proceeds
    // exactly as before.
    List<QpcV4RenderBlock> blocks = widget.quranCtrl
        .getQpcLayoutBlocksForPageSync(widget.pageIndex + 1);
    while (blocks.isEmpty) {
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return;
      blocks = widget.quranCtrl
          .getQpcLayoutBlocksForPageSync(widget.pageIndex + 1);
    }
    final total = blocks.length;

    int next = _builtBlocks <= 0 ? 0 : _builtBlocks;
    while (next < total) {
      // Wait for the current frame to finish before we touch state.
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return;
      // [iqama fork — Q14 gates] Pause this page's incremental
      // promotion while EITHER of:
      //   • the user is mid-swipe (`recommendDeferredLoading`
      //     returns true while velocity > kMinFlingVelocity);
      //   • this page isn't currently the focused one (it's living
      //     in the keep-alive cache).
      //
      // The visibility gate is important: without it, ~9
      // off-screen cache pages all run their own per-frame
      // promotion concurrently with the focused page, blowing the
      // 16 ms frame budget many times over and reproducing exactly
      // the lag we're trying to remove. With the gate, only the
      // page you're looking at promotes; everyone else freezes
      // wherever they are and resumes when you swipe to them.
      while (mounted && (
        widget.quranCtrl.state.currentPageNumber.value !=
            widget.pageIndex + 1 ||
        (Scrollable.maybeOf(context) != null &&
            Scrollable.recommendDeferredLoadingForContext(context))
      )) {
        await SchedulerBinding.instance.endOfFrame;
        if (!mounted) return;
      }
      next++;
      // [iqama fork — Q14 batching] Surah headers and basmallah
      // blocks are cheap (no RichText / text-shaping), so fold any
      // that immediately follow this promotion into the same
      // setState. Reduces the total promotion count from ~15 to
      // ~12 on a typical page and stops the visible
      // "header-appears-then-basmallah-appears-then-line-appears"
      // stutter on a Surah-start page.
      while (next < total &&
          (blocks[next] is QpcV4SurahHeaderBlock ||
              blocks[next] is QpcV4BasmallahBlock)) {
        next++;
      }
      setState(() => _builtBlocks = next);
    }

    if (!mounted) return;
    _pageBuildEverFullyRendered.add(widget.pageIndex);
    if (_builtBlocks != -1) {
      setState(() => _builtBlocks = -1);
    }
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

    // [iqama fork] Nothing built yet → empty page-sized
    // placeholder. Cheap render that occupies the full PageView
    // slot so the layout stays well-formed during the swipe.
    if (_builtBlocks == 0) {
      return const SizedBox.expand();
    }

    final fullyRendered = _builtBlocks == -1;
    // [iqama fork] When still mid-incremental-build we render
    // blocks[0..N-1] as real widgets and the rest as
    // line-height-shaped placeholders. The placeholders match the
    // approximate height of an ayah line so the page doesn't
    // jiggle visibly as blocks promote one frame at a time.
    return RepaintBoundary(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: blocks.asMap().entries.map((entry) {
            final blockIndex = entry.key;
            final b = entry.value;
            if (!fullyRendered && blockIndex >= _builtBlocks) {
              return const SizedBox(height: 36);
            }
            return _renderBlock(
              b: b,
              context: context,
              surahFilterNumber: surahFilterNumber,
              bannerStyle: bannerStyle,
              isDark: isDark,
              surahNameStyle: surahNameStyle,
              onSurahBannerPress: onSurahBannerPress,
              basmalaStyle: basmalaStyle,
              textColor: textColor,
              bookmarks: bookmarks,
              onAyahLongPress: onAyahLongPress,
              bookmarkList: bookmarkList,
              ayahIconColor: ayahIconColor,
              showAyahBookmarkedIcon: showAyahBookmarkedIcon,
              bookmarksAyahs: bookmarksAyahs,
              bookmarksColor: bookmarksColor,
              customBookmarksColor: customBookmarksColor,
              ayahSelectedBackgroundColor: ayahSelectedBackgroundColor,
              isFontsLocal: isFontsLocal,
              fontsName: fontsName,
              ayahBookmarked: ayahBookmarked,
              isAyahBookmarked: isAyahBookmarked,
              onPagePress: onPagePress,
              pageIndex: pageIndex,
              quranCtrl: quranCtrl,
            );
          }).toList(),
        ),
      ),
    );
  }

  /// [iqama fork] Extracted from the original inline `blocks.map(…)`
  /// closure so the incremental-build path can short-circuit a
  /// not-yet-promoted block to a cheap `SizedBox(height: …)` while
  /// still calling this helper for the promoted ones. Behaviour for
  /// each block type is unchanged.
  Widget _renderBlock({
    required QpcV4RenderBlock b,
    required BuildContext context,
    required int? surahFilterNumber,
    required BannerStyle? bannerStyle,
    required bool isDark,
    required SurahNameStyle? surahNameStyle,
    required Function(SurahNamesModel)? onSurahBannerPress,
    required BasmalaStyle? basmalaStyle,
    required Color? textColor,
    required Map<int, List<BookmarkModel>> bookmarks,
    required Function(LongPressStartDetails, AyahModel)? onAyahLongPress,
    required List? bookmarkList,
    required Color? ayahIconColor,
    required bool showAyahBookmarkedIcon,
    required List<int> bookmarksAyahs,
    required Color? bookmarksColor,
    required Color? Function(AyahModel)? customBookmarksColor,
    required Color? ayahSelectedBackgroundColor,
    required bool? isFontsLocal,
    required String? fontsName,
    required List<int> ayahBookmarked,
    required bool Function(AyahModel)? isAyahBookmarked,
    required VoidCallback? onPagePress,
    required int pageIndex,
    required QuranCtrl quranCtrl,
  }) {
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
            SurahNameStyle.downloadFonts(isDark: isDark, context: context),
        onSurahBannerPress: onSurahBannerPress,
        isDark: isDark,
      );
    }

    if (b is QpcV4BasmallahBlock) {
      return BasmallahWidget(
        surahNumber: b.surahNumber,
        basmalaStyle: basmalaStyle ??
            BasmalaStyle.downloadFonts(isDark: isDark, context: context),
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
  }
}
