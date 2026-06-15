part of '/quran.dart';

/// Bookmarks (fawasl) panel inside the [QuranHubSheet]. The
/// library tracks bookmarks as a `Map<int, List<BookmarkModel>>`
/// keyed by colour code — each colour is a user-chosen marker
/// (yellow, green, etc.). This panel renders that map directly:
/// one section per colour, sorted by colour code so the
/// presentation stays stable across runs; each section lists the
/// bookmarks under it with the surah + ayah label, the page
/// number, and tap-to-jump + swipe-to-delete affordances.
///
/// Empty state: an explanatory line telling the user how to
/// bookmark — tap an ayah → ⭐ button. Slice 5 wires that
/// flow up in the new ayah tap menu; today the only entry point
/// is the legacy long-press dialog.
class QuranHubBookmarksPanel extends StatelessWidget {
  final QuranThemePalette palette;
  final String languageCode;

  const QuranHubBookmarksPanel({
    super.key,
    required this.palette,
    required this.languageCode,
  });

  bool get _isAr => languageCode == 'ar';

  @override
  Widget build(BuildContext context) {
    final palette = this.palette;
    return GetBuilder<BookmarksCtrl>(
      // BookmarksCtrl ships an `update()` after each save/remove —
      // GetBuilder picks that up and rebuilds. No need for Obx.
      builder: (ctrl) {
        final byColour = ctrl.bookmarks.entries
            // Skip empty buckets so an old colour with no entries
            // doesn't render a ghost section.
            .where((e) => e.value.isNotEmpty)
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        if (byColour.isEmpty) {
          return _BookmarksEmptyState(palette: palette, isAr: _isAr);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          children: [
            for (final entry in byColour) ...[
              _ColourSectionHeader(
                palette: palette,
                colour: Color(entry.key),
                count: entry.value.length,
                isAr: _isAr,
              ),
              for (final b in entry.value)
                _BookmarkRow(
                  palette: palette,
                  bookmark: b,
                  isAr: _isAr,
                  onJump: () {
                    Navigator.of(context).maybePop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      QuranLibrary().jumpToBookmark(b);
                    });
                  },
                  onDelete: () => ctrl.removeBookmark(b.id),
                ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _BookmarksEmptyState extends StatelessWidget {
  final QuranThemePalette palette;
  final bool isAr;
  const _BookmarksEmptyState({required this.palette, required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border_rounded, size: 40, color: palette.subInk),
            const SizedBox(height: 12),
            Text(
              isAr ? 'لا توجد فواصل بعد' : 'No bookmarks yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isAr
                  ? 'اضغط على آية في الصفحة ثم اختر الفاصل لتخزينها هنا'
                  : 'Tap an ayah on the page, choose a bookmark colour, and it shows up here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: palette.subInk,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColourSectionHeader extends StatelessWidget {
  final QuranThemePalette palette;
  final Color colour;
  final int count;
  final bool isAr;
  const _ColourSectionHeader({
    required this.palette,
    required this.colour,
    required this.count,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      child: Row(
        children: [
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: palette.divider),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isAr ? 'فاصل ملوّن' : 'Colour group',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: palette.subInk,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                  palette.accent.withValues(alpha: 0.10), palette.surface),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: palette.accent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkRow extends StatelessWidget {
  final QuranThemePalette palette;
  final BookmarkModel bookmark;
  final bool isAr;
  final VoidCallback onJump;
  final VoidCallback onDelete;
  const _BookmarkRow({
    required this.palette,
    required this.bookmark,
    required this.isAr,
    required this.onJump,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('bookmark_${bookmark.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 18),
        color: const Color(0xFFC4524C),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onJump,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 8, height: 28,
                decoration: BoxDecoration(
                  color: Color(bookmark.colorCode),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bookmark.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAr
                          ? 'الآية ${bookmark.ayahNumber} · صفحة ${bookmark.page}'
                          : 'Ayah ${bookmark.ayahNumber} · Page ${bookmark.page}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: palette.subInk,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: palette.subInk),
            ],
          ),
        ),
      ),
    );
  }
}
