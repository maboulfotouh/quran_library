part of '/quran.dart';

class _QuranTopBar extends StatelessWidget {
  final String languageCode;
  final bool isDark;
  final SurahAudioStyle? style;
  final bool? isFontsLocal;
  final DownloadFontsDialogStyle? downloadFontsDialogStyle;
  final Color? backgroundColor;
  final bool? isSingleSurah;
  final bool? isPagesView;

  const _QuranTopBar(
    this.languageCode,
    this.isDark, {
    this.style,
    this.isFontsLocal,
    this.downloadFontsDialogStyle,
    this.backgroundColor,
    this.isSingleSurah = false,
    this.isPagesView = false,
  });

  @override
  Widget build(BuildContext context) {
    // Centralized theming (read from theme or fallback to defaults)
    final QuranTopBarStyle defaults = QuranTopBarTheme.of(context)?.style ??
        QuranTopBarStyle.defaults(isDark: isDark, context: context);

    final TajweedMenuStyle tajweedStyle = TajweedMenuTheme.of(context)?.style ??
        TajweedMenuStyle.defaults(isDark: isDark, context: context);
    final Color bgColor = backgroundColor ??
        (defaults.backgroundColor ?? AppColors.getBackgroundColor(isDark));

    // [iqama fork] Iqama-style chrome: white surface, hairline
    // bottom divider in place of a heavy drop shadow, rounded
    // Material icons instead of bespoke SVGs. Buttons rendered as
    // _TopBarIconButton so each icon sits inside a tealTint pill
    // that lights up to teal when the action is in an "on" state
    // (auto-scroll active, tajweed visible, etc).
    final iconColor = defaults.iconColor ?? AppColors.tealDeep;
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: defaults.height ?? 56,
        padding: defaults.padding ??
            const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: Row(
          children: [
            if (defaults.showBackButton ?? false)
              _TopBarIconButton(
                icon: Icons.arrow_back_rounded,
                color: iconColor,
                onPressed: () => Navigator.pop(context),
              ),
            if (defaults.showMenuButton ?? true)
              _TopBarIconButton(
                icon: Icons.menu_book_rounded,
                color: iconColor,
                onPressed: () {
                  QuranCtrl.instance.searchFocusNode.requestFocus();
                  _showMenuBottomSheet(context, defaults);
                },
              ),
            if ((defaults.showMenuButton ?? true) &&
                (QuranCtrl.instance.state.fontsSelected.value == 0))
              _TopBarIconButton(
                icon: Icons.format_paint_rounded,
                color: iconColor,
                tooltip: 'Tajweed',
                onPressed: () => _showDialog(context, tajweedStyle),
              ),
            const Spacer(),
            if (defaults.customTopBarWidgets != null)
              ...defaults.customTopBarWidgets!,
            const Spacer(),
            Row(
              children: [
                if (defaults.showAutoScrollButton ?? true)
                  Obx(() {
                    final isAutoScrollActive =
                        AutoScrollCtrl.instance.state.isActive.value;
                    return QuranCtrl.instance.state.displayMode.value ==
                            QuranDisplayMode.defaultMode
                        ? _TopBarIconButton(
                            icon: Icons.swap_vert_rounded,
                            color: iconColor,
                            active: isAutoScrollActive,
                            onPressed: () {
                              final ctrl = AutoScrollCtrl.instance;
                              if (ctrl.state.isActive.value) {
                                ctrl.stopAutoScroll();
                              } else {
                                final currentPage = QuranCtrl
                                    .instance.state.currentPageNumber.value;
                                ctrl.startAutoScroll(currentPage);
                              }
                            },
                          )
                        : const SizedBox.shrink();
                  }),
                if (defaults.showAudioButton ?? true)
                  _TopBarIconButton(
                    icon: Icons.headphones_rounded,
                    color: iconColor,
                    onPressed: () async {
                      await AudioCtrl.instance.state.audioPlayer.stop();
                      QuranCtrl.instance.state.isShowMenu.value = false;
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SurahAudioScreen(
                              isDark: isDark,
                              style: style ??
                                  SurahAudioStyle.defaults(
                                      isDark: isDark, context: context),
                              languageCode: languageCode,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                if ((defaults.showFontsButton ?? true) && (!isSingleSurah!) ||
                    (isPagesView!))
                  FontsDownloadDialog(
                    downloadFontsDialogStyle: downloadFontsDialogStyle ??
                        DownloadFontsDialogStyle.defaults(isDark, context),
                    languageCode: languageCode,
                    isFontsLocal: isFontsLocal,
                    isDark: isDark,
                  )
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showDialog(BuildContext context, TajweedMenuStyle defaults) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: backgroundColor ??
            defaults.backgroundColor ??
            AppColors.getBackgroundColor(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(defaults.borderRadius ?? 12),
        ),
        child: TajweedMenuWidget(isDark: isDark, languageCode: languageCode),
      ),
    );
  }

  void _showMenuBottomSheet(BuildContext context, QuranTopBarStyle defaults) {
    // التقط الأنماط من الـ Theme قبل الدخول لحدود bottom sheet
    final indexTabStyle = IndexTabTheme.of(context)?.style ??
        IndexTabStyle.defaults(isDark: isDark, context: context);
    final searchTabStyle = SearchTabTheme.of(context)?.style ??
        SearchTabStyle.defaults(isDark: isDark, context: context);
    final bookmarksTabStyle = BookmarksTabTheme.of(context)?.style ??
        BookmarksTabStyle.defaults(isDark: isDark, context: context);

    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundColor ??
          defaults.backgroundColor ??
          AppColors.getBackgroundColor(isDark),
      // [iqama fork] 24px top corners to match the rest of the app's
      // bottom sheets (daily-actions, member-stats, league-created).
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: UiHelper.currentOrientation(
            double.infinity, MediaQuery.sizeOf(context).width * 0.5, context),
      ),
      builder: (ctx) => _MenuBottomSheet(
        isDark: isDark,
        languageCode: languageCode,
        backgroundColor: backgroundColor,
        style: defaults,
        indexTabStyle: indexTabStyle,
        searchTabStyle: searchTabStyle,
        bookmarksTabStyle: bookmarksTabStyle,
        isSingleSurah: isSingleSurah!,
      ),
    );
  }
}

// BottomSheet container with main TabBar
class _MenuBottomSheet extends StatelessWidget {
  final bool isDark;
  final String languageCode;
  final Color? backgroundColor;
  final QuranTopBarStyle style;
  final IndexTabStyle indexTabStyle;
  final SearchTabStyle searchTabStyle;
  final BookmarksTabStyle bookmarksTabStyle;
  final bool isSingleSurah;

  const _MenuBottomSheet({
    required this.isDark,
    required this.languageCode,
    this.backgroundColor,
    required this.style,
    required this.indexTabStyle,
    required this.searchTabStyle,
    required this.bookmarksTabStyle,
    this.isSingleSurah = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor = style.textColor ?? AppColors.getTextColor(isDark);
    final Color accentColor =
        style.accentColor ?? Theme.of(context).colorScheme.primary;

    return DefaultTabController(
      length: isSingleSurah ? 2 : 3,
      child: SafeArea(
        top: false,
        child: Container(
          height: UiHelper.currentOrientation(
              MediaQuery.of(context).size.height * 0.8,
              MediaQuery.of(context).size.height * .9,
              context),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // [iqama fork] Drag handle uses the Iqama divider
              // color for visual continuity with our other sheets.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: style.handleColor ?? AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // [iqama fork] Segmented pill matches the rest of the
              // app's pill-style toggles — tealTint track, teal
              // selected pill with white label, ink unselected text.
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.tealTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.teal.withValues(alpha: 0.20),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorPadding:
                      style.indicatorPadding ?? const EdgeInsets.all(4),
                  dividerColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.tealDeep,
                  indicatorColor: accentColor,
                  indicatorWeight: .5,
                  labelStyle: QuranLibrary().cairoStyle.copyWith(
                      fontSize: 14, fontWeight: FontWeight.w700, height: 1.3,
                      letterSpacing: -0.1),
                  unselectedLabelStyle: QuranLibrary().cairoStyle.copyWith(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      letterSpacing: -0.1),
                  tabs: [
                    if (!isSingleSurah)
                      Tab(text: style.tabIndexLabel ?? 'الفهرس'),
                    Tab(text: style.tabSearchLabel ?? 'البحث'),
                    Tab(text: style.tabBookmarksLabel ?? 'الفواصل'),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: TabBarView(
                  children: [
                    if (!isSingleSurah)
                      _IndexTab(
                        isDark: isDark,
                        languageCode: languageCode,
                        style: indexTabStyle,
                      ),
                    _SearchTab(
                      isDark: isDark,
                      languageCode: languageCode,
                      style: searchTabStyle,
                    ),
                    _BookmarksTab(
                      isDark: isDark,
                      languageCode: languageCode,
                      style: bookmarksTabStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Iqama-style top-bar icon button ─────────────────────────────────────────

/// [iqama fork] Square 40×40 button with a tealTint backdrop pill
/// that brightens to full teal when [active] is true. Used by every
/// action in the Quran top bar so the chrome reads as a row of
/// equally-weighted, tappable affordances rather than bare SVGs.
class _TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onPressed;
  final String? tooltip;

  const _TopBarIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.active = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: active ? AppColors.teal : AppColors.tealTint,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: active ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: button) : button;
  }
}

