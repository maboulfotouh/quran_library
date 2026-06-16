part of '/quran.dart';

/// Five-card walkthrough shown once per install the first time a
/// user opens the reader after the page fonts have finished
/// downloading. Walks through the redesigned controls so the
/// floating-pill chrome / Hub / tap-ayah menu / theme cycle /
/// tajweed quick toggle aren't undiscovered surface area.
///
/// **Persistence.** A "seen" flag is written to GetStorage under
/// [_seenKey] after the user finishes or skips the flow. Once set,
/// [QuranOnboarding.maybeShow] returns without showing the overlay
/// — the user opts back into it only by clearing storage.
///
/// **Trigger from the consumer.** The mobile wrapper calls
/// [QuranOnboarding.maybeShow] after its `_initialFontReady`
/// resolves. That's the cleanest moment because the reader is
/// about to be visible AND fonts are loaded, so the spotlight on
/// "tap an ayah" won't land on an unrendered page.
///
/// **Localization.** Strings are inlined (Arabic + English),
/// keyed off the language code the consumer passes. Consumer
/// doesn't need to thread an l10n delegate through the library.
class QuranOnboarding {
  QuranOnboarding._();

  /// GetStorage key the "user has seen onboarding" flag is
  /// written under. Bumped when the flow changes materially so
  /// existing users see the new content.
  static const _seenKey = 'quran_onboarding_seen_v1';

  /// True iff the user has already finished or skipped onboarding
  /// at least once. Consumers can read this to gate other
  /// first-run-only UI of their own.
  static bool get hasSeen =>
      GetStorage().read<bool>(_seenKey) ?? false;

  /// Marks the flow as seen. Auto-called when the user finishes or
  /// skips; exposed so a consumer can pre-mark it for users who
  /// downloaded the app before the redesign and don't need a
  /// tutorial for screens they've been using all along.
  static Future<void> markSeen() async {
    await GetStorage().write(_seenKey, true);
  }

  /// Resets the flag so the next reader open re-shows the tour.
  /// Useful from a debug menu or as a "show me again" link.
  static Future<void> reset() async {
    await GetStorage().remove(_seenKey);
  }

  /// Conditionally shows the overlay. No-ops when [hasSeen] is
  /// already true. Use [force] when wiring a "Show me again"
  /// affordance.
  ///
  /// Awaits the user's dismissal so callers can chain follow-up
  /// behaviour — e.g. start a backend version-check campaign
  /// only after the user has been onboarded.
  static Future<void> maybeShow(
    BuildContext context, {
    required String languageCode,
    bool force = false,
  }) async {
    if (!force && hasSeen) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _QuranOnboardingScaffold(languageCode: languageCode),
    );
    await markSeen();
  }
}

class _QuranOnboardingScaffold extends StatefulWidget {
  final String languageCode;

  const _QuranOnboardingScaffold({required this.languageCode});

  @override
  State<_QuranOnboardingScaffold> createState() =>
      _QuranOnboardingScaffoldState();
}

class _QuranOnboardingScaffoldState extends State<_QuranOnboardingScaffold> {
  final _ctrl = PageController();
  int _page = 0;
  late final List<_OnboardingCardSpec> _specs = _buildSpecs(widget.languageCode);

  bool get _isAr => widget.languageCode == 'ar';
  bool get _isLast => _page >= _specs.length - 1;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      Navigator.of(context).maybePop();
      return;
    }
    _ctrl.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    _ctrl.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = QuranCtrl.instance.state.quranTheme.value.palette;
    final mq = MediaQuery.of(context);
    return Directionality(
      textDirection: _isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 460,
            maxHeight: mq.size.height * 0.86,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Header(
                    palette: palette,
                    skipLabel: _isAr ? 'تخطي' : 'Skip',
                    progress: '${_page + 1} / ${_specs.length}',
                    onSkip: () => Navigator.of(context).maybePop(),
                  ),
                  Flexible(
                    child: PageView.builder(
                      controller: _ctrl,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemCount: _specs.length,
                      itemBuilder: (_, i) => _OnboardingCard(
                        spec: _specs[i],
                        palette: palette,
                      ),
                    ),
                  ),
                  _DotIndicator(
                    palette: palette,
                    count: _specs.length,
                    activeIndex: _page,
                  ),
                  _Footer(
                    palette: palette,
                    isAr: _isAr,
                    canGoBack: _page > 0,
                    isLast: _isLast,
                    onBack: _back,
                    onNext: _next,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final QuranThemePalette palette;
  final String skipLabel;
  final String progress;
  final VoidCallback onSkip;

  const _Header({
    required this.palette,
    required this.skipLabel,
    required this.progress,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 14, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                  palette.accent.withValues(alpha: 0.12), palette.surface),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              progress,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: palette.accent,
                letterSpacing: 0.6,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: palette.subInk,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              skipLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  final _OnboardingCardSpec spec;
  final QuranThemePalette palette;

  const _OnboardingCard({required this.spec, required this.palette});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                    palette.accent.withValues(alpha: 0.07),
                    palette.pageBackground),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.divider),
              ),
              clipBehavior: Clip.antiAlias,
              child: spec.illustration(palette),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            spec.title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: palette.ink,
              letterSpacing: -0.3,
              height: 1.25,
            ),
          ),
          if (spec.intro != null) ...[
            const SizedBox(height: 8),
            Text(
              spec.intro!,
              style: TextStyle(
                fontSize: 14,
                color: palette.subInk,
                height: 1.55,
                letterSpacing: -0.05,
              ),
            ),
          ],
          if (spec.items != null) ...[
            const SizedBox(height: 12),
            for (final item in spec.items!) ...[
              _OnboardingItemRow(item: item, palette: palette),
              if (item != spec.items!.last) const SizedBox(height: 10),
            ],
          ],
          if (spec.body != null) ...[
            SizedBox(height: spec.items != null ? 12 : 8),
            Text(
              spec.body!,
              style: TextStyle(
                fontSize: 14,
                color: palette.subInk,
                height: 1.55,
                letterSpacing: -0.05,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A single icon + description row inside an onboarding card's
/// bullet list. The icon is rendered in a faint accent-tinted
/// circle so it reads visually as a chip the user can match to
/// the real chrome control once the tour closes.
class _OnboardingItemRow extends StatelessWidget {
  final _OnboardingItem item;
  final QuranThemePalette palette;

  const _OnboardingItemRow({required this.item, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
                palette.accent.withValues(alpha: 0.10),
                palette.surface),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.divider),
          ),
          alignment: Alignment.center,
          child: Icon(item.icon, size: 18, color: palette.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              item.text,
              style: TextStyle(
                fontSize: 14,
                color: palette.subInk,
                height: 1.5,
                letterSpacing: -0.05,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final QuranThemePalette palette;
  final int count;
  final int activeIndex;

  const _DotIndicator({
    required this.palette,
    required this.count,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == activeIndex ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == activeIndex
                    ? palette.accent
                    : palette.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final QuranThemePalette palette;
  final bool isAr;
  final bool canGoBack;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _Footer({
    required this.palette,
    required this.isAr,
    required this.canGoBack,
    required this.isLast,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final nextLabel = isLast
        ? (isAr ? 'ابدأ' : 'Start reading')
        : (isAr ? 'التالي' : 'Next');
    final backLabel = isAr ? 'السابق' : 'Back';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
      child: Row(
        children: [
          if (canGoBack)
            TextButton(
              onPressed: onBack,
              style: TextButton.styleFrom(
                foregroundColor: palette.subInk,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: Text(
                backLabel,
                style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const Spacer(),
          Material(
            color: palette.accent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onNext,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nextLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: palette.surface,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isLast
                          ? Icons.menu_book_rounded
                          : (isAr
                              ? Icons.arrow_back_rounded
                              : Icons.arrow_forward_rounded),
                      size: 16,
                      color: palette.surface,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One card in the tour. Illustrations are drawn from inline
/// widgets — no asset dependency — so the package stays small
/// and the illustration colours pick up the active palette.
///
/// A card can render any combination of:
///   • [intro] — a short paragraph below the title (e.g. the "the
///     top bar has these tools" lead-in for the toolbar card).
///   • [items] — a bullet list with a real icon on the left + a
///     short description on the right. The icons are the same
///     instances the reader chrome uses, so the user can match
///     them visually as soon as they close the tour.
///   • [body] — a closing paragraph for cards that don't need a
///     bullet list (welcome + mark-this-page).
///
/// Any of the three is optional — the rendering walks them in
/// order and skips nulls.
class _OnboardingCardSpec {
  final String title;
  final String? intro;
  final List<_OnboardingItem>? items;
  final String? body;
  final Widget Function(QuranThemePalette palette) illustration;

  const _OnboardingCardSpec({
    required this.title,
    this.intro,
    this.items,
    this.body,
    required this.illustration,
  });
}

class _OnboardingItem {
  final IconData icon;
  final String text;
  const _OnboardingItem({required this.icon, required this.text});
}

List<_OnboardingCardSpec> _buildSpecs(String languageCode) {
  final isAr = languageCode == 'ar';
  return [
    // ── 1. Welcome ───────────────────────────────────────────────────
    _OnboardingCardSpec(
      title: isAr ? 'مرحبًا في مصحفك' : 'Welcome to your Mushaf',
      body: isAr
        ? 'أثناء تهيئة المصحف. يمكنك أخذ جولة قصيرة للتعرّف على طريقة استخدامه وأدواته، لتقرأ براحة أكبر.'
        : 'The Mushaf is being prepared. You can take a quick tour to learn how to use it and its tools, so you can read more comfortably.',
      illustration: _WelcomeIllustration.new,
    ),

    // ── 2. Top bar — icon list (theme cycle + tajweed + Hub teaser) ──
    _OnboardingCardSpec(
      title: isAr ? 'شريط المهام' : 'The top bar',
      intro: isAr
          ? 'في أعلى الصفحة يوجد شريط صغير يجمع أكثر الأدوات استخدامًا. هذه أيقوناته:'
          : 'A small bar sits at the top of every page with the tools you use most. Here is what each icon does:',
      items: [
        _OnboardingItem(
          icon: Icons.light_mode_rounded,
          text: isAr
              ? 'تبديل المظهر: فاتح → داكن → بُني. اضغط مرة لتنتقل إلى المظهر التالي، وستذكر اختيارك في كل فتحة قادمة.'
              : 'Theme cycle: Light → Dark → Sepia. Tap once to move to the next mode; your choice is remembered next time.',
        ),
        _OnboardingItem(
          icon: Icons.brush_rounded,
          text: isAr
              ? 'تشغيل أو إيقاف ألوان التجويد على نص المصحف من نفس مكان القراءة.'
              : 'Turn the tajweed colouring on or off without leaving the page.',
        ),
        _OnboardingItem(
          icon: Icons.tune_rounded,
          text: isAr
              ? 'الإعدادات: تفتح نافذة تجمع كل الأدوات (السور، الفواصل، البحث، التحميلات، الخيارات). تفاصيلها في الصفحة التالية.'
              : 'Settings: opens the Hub — surahs, bookmarks, search, downloads, options. The next slide breaks each one down.',
        ),
      ],
      illustration: _TopBarIllustration.new,
    ),

    // ── 3. Settings sheet (Hub) — bullet per tab ──────────────────────
    _OnboardingCardSpec(
      title: isAr ? 'الإعدادات: كل الأدوات في مكان واحد' : 'Inside the settings sheet',
      intro: isAr
          ? 'حين تضغط على أيقونة الإعدادات تفتح نافذة بخمسة أقسام:'
          : 'Tapping the settings icon opens a sheet with five sections:',
      items: [
        _OnboardingItem(
          icon: Icons.menu_book_rounded,
          text: isAr
              ? 'السور: قائمة الـ 114 سورة مرتّبة. اضغط على أي اسم لتنتقل مباشرة إلى أول صفحة فيها.'
              : 'Surahs: the full 114-surah list. Tap a surah to jump straight to its first page.',
        ),
        _OnboardingItem(
          icon: Icons.bookmark_rounded,
          text: isAr
              ? 'الفواصل: كل الآيات التي حفظتها بألوان مختلفة، يمكنك العودة لأي منها بضغطة، أو حذفها.'
              : 'Bookmarks: every ayah you have saved (with its colour). Tap one to jump back to it, or remove it.',
        ),
        _OnboardingItem(
          icon: Icons.search_rounded,
          text: isAr
              ? 'البحث: ابحث عن كلمة أو جزء من آية وستظهر النتائج مع موقعها في المصحف.'
              : 'Search: find a word or part of an ayah; matches show with their surah + page.',
        ),
        _OnboardingItem(
          icon: Icons.download_rounded,
          text: isAr
              ? 'التحميلات: تحكّم في تنزيل تلاوات القرّاء واستماعها لاحقًا بدون إنترنت.'
              : 'Downloads: pick reciters to download for offline listening.',
        ),
        _OnboardingItem(
          icon: Icons.tune_rounded,
          text: isAr
              ? 'الخيارات: المظهر، التجويد، حجم الخط، وغيرها من إعدادات القراءة في مكان واحد.'
              : 'Options: theme, tajweed, font size and the other reader-wide preferences in one place.',
        ),
      ],
      illustration: _HubIllustration.new,
    ),

    // ── 4. Long-press an ayah — bullet per action ─────────────────────
    _OnboardingCardSpec(
      title:
          isAr ? 'اضغط على الآية مطوّلًا للمزيد' : 'Long-press an ayah for more',
      intro: isAr
          ? 'الضغط المطوّل على أي آية يفتح قائمة سريعة بأربعة خيارات:'
          : 'Long-pressing any ayah opens a quick menu with four actions:',
      items: [
        _OnboardingItem(
          icon: Icons.play_arrow_rounded,
          text: isAr
              ? 'استماع: تشغيل تلاوة الآية بصوت القارئ الذي اخترته.'
              : 'Play: hear the ayah recited by your selected reciter.',
        ),
        _OnboardingItem(
          icon: Icons.menu_book_rounded,
          text: isAr
              ? 'التفسير: عرض تفسير الآية في النافذة نفسها بدون مغادرة الصفحة.'
              : 'Tafsir: read the ayah\'s tafsir right inside the sheet — no page change.',
        ),
        _OnboardingItem(
          icon: Icons.bookmark_add_rounded,
          text: isAr
              ? 'فاصل ملوّن: احفظ الآية بلون مختار من ستة ألوان للرجوع إليها لاحقًا.'
              : 'Bookmark: save the ayah with one of six colours so you can come back to it later.',
        ),
        _OnboardingItem(
          icon: Icons.copy_rounded,
          text: isAr
              ? 'نسخ: انسخ نص الآية إلى الحافظة لتشاركها أو تحفظها.'
              : 'Copy: copy the ayah text to the clipboard for sharing or saving.',
        ),
      ],
      illustration: _AyahMenuIllustration.new,
    ),

    // ── 5. Mark each finished page — pill is at the TOP, not bottom ──
    _OnboardingCardSpec(
      title:
          isAr ? 'تتبّع قراءتك اليومية' : 'Mark each page you finish',
      body: isAr
          ? 'بأعلى كل صفحة زر صغير. اضغطه عند انتهائك من قراءة الصفحة لتضاف نقطة إلى رصيدك اليومي ويُحفظ تقدّمك.'
          : 'A small pill sits at the top of every page. Tap it after you finish reading the page to add a point to your daily score and save your progress.',
      illustration: _MarkPageIllustration.new,
    ),
  ];
}

// ─── Inline illustrations ─────────────────────────────────────────────────────
//
// All illustrations are small custom-painted scenes that mimic the
// real UI element a card describes. Drawing inline (instead of
// shipping SVGs / PNGs as assets) keeps the package size small and
// lets the strokes pick up the active QuranThemePalette so the
// onboarding self-recolours on Light → Dark → Sepia.

class _WelcomeIllustration extends StatelessWidget {
  final QuranThemePalette palette;
  const _WelcomeIllustration(this.palette);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                  palette.accent.withValues(alpha: 0.18),
                  palette.pageBackground),
              shape: BoxShape.circle,
            ),
          ),
          Icon(
            Icons.menu_book_rounded,
            size: 56,
            color: palette.accent,
          ),
        ],
      ),
    );
  }
}

class _TopBarIllustration extends StatelessWidget {
  final QuranThemePalette palette;
  const _TopBarIllustration(this.palette);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _MockPill(
            palette: palette,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded,
                      size: 12, color: palette.ink),
                  const SizedBox(width: 4),
                  Container(
                    width: 28, height: 6,
                    decoration: BoxDecoration(
                      color: palette.ink.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _MockPill(
            palette: palette,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22, height: 18,
                    alignment: Alignment.center,
                    child: Container(
                      width: 22, height: 5,
                      decoration: BoxDecoration(
                        color: palette.ink.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _MockIcon(palette: palette, icon: Icons.dark_mode_rounded,
                      highlighted: true),
                  const SizedBox(width: 4),
                  _MockIcon(palette: palette, icon: Icons.brush_rounded,
                      highlighted: true),
                  const SizedBox(width: 4),
                  _MockIcon(palette: palette, icon: Icons.tune_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubIllustration extends StatelessWidget {
  final QuranThemePalette palette;
  const _HubIllustration(this.palette);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      Icons.menu_book_rounded,
      Icons.bookmark_rounded,
      Icons.search_rounded,
      Icons.download_rounded,
      Icons.tune_rounded,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < tabs.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: i == 0
                        ? Color.alphaBlend(
                            palette.accent.withValues(alpha: 0.12),
                            palette.surface)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: i == 0
                          ? palette.accent
                          : palette.divider,
                    ),
                  ),
                  child: Icon(
                    tabs[i],
                    size: 14,
                    color: i == 0 ? palette.accent : palette.subInk,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AyahMenuIllustration extends StatelessWidget {
  final QuranThemePalette palette;
  const _AyahMenuIllustration(this.palette);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Stack(
        children: [
          // Mock ayah lines.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _MockLine(palette: palette, width: 0.85),
              const SizedBox(height: 8),
              _MockLine(palette: palette, width: 0.65),
              const SizedBox(height: 8),
              _MockLine(palette: palette, width: 0.78),
            ],
          ),
          // Floating action sheet preview.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MockIcon(palette: palette, icon: Icons.play_arrow_rounded),
                  _MockIcon(palette: palette, icon: Icons.menu_book_rounded),
                  _MockIcon(palette: palette, icon: Icons.bookmark_add_rounded),
                  _MockIcon(palette: palette, icon: Icons.copy_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkPageIllustration extends StatelessWidget {
  final QuranThemePalette palette;
  const _MarkPageIllustration(this.palette);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _MockLine(palette: palette, width: 0.82),
          _MockLine(palette: palette, width: 0.95),
          _MockLine(palette: palette, width: 0.7),
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 14, color: palette.surface),
                  const SizedBox(width: 6),
                  Container(
                    width: 56, height: 6,
                    decoration: BoxDecoration(
                      color: palette.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockPill extends StatelessWidget {
  final QuranThemePalette palette;
  final Widget child;

  const _MockPill({required this.palette, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MockIcon extends StatelessWidget {
  final QuranThemePalette palette;
  final IconData icon;
  final bool highlighted;

  const _MockIcon({
    required this.palette,
    required this.icon,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: highlighted
          ? BoxDecoration(
              color: Color.alphaBlend(
                  palette.accent.withValues(alpha: 0.18),
                  palette.surface),
              shape: BoxShape.circle,
            )
          : null,
      child: Icon(
        icon,
        size: 13,
        color: highlighted ? palette.accent : palette.ink,
      ),
    );
  }
}

class _MockLine extends StatelessWidget {
  final QuranThemePalette palette;
  final double width;

  const _MockLine({required this.palette, required this.width});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        height: 8,
        width: constraints.maxWidth * width,
        decoration: BoxDecoration(
          color: palette.ink.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
