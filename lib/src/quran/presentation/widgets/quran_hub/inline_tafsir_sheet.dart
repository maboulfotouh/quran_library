part of '/quran.dart';

/// Thin chrome wrapper around the existing [ShowTafseer] widget.
/// The legacy tafsir sheet ships its own visual chrome (handle,
/// title bar, tabs) and a heap of style customisation knobs;
/// rather than duplicate all of that, this wrapper pre-builds a
/// matching [TafsirStyle] from the active [QuranThemePalette] so
/// the existing tafsir UI inherits the new theme:
///
///   * Background = palette.surface
///   * Text + icon colours = palette.ink / palette.subInk
///   * Accent + active tab = palette.accent
///
/// **Why reuse?** The legacy ShowTafseer handles a lot — multiple
/// tafsir sources, downloads, font-size sliders, the
/// tajweed-aya tab. Reimplementing that surface from scratch
/// would be a fork-on-fork. The right move is to keep the body
/// and only redress its chrome.
///
/// **Modal lifecycle.** Opened with [show] from the
/// [AyahActionSheet]'s Tafsir button. Returns a Future for
/// callers that want to chain follow-up state changes.
class InlineTafsirSheet extends StatelessWidget {
  final AyahModel ayah;
  final int pageIndex;
  final String languageCode;

  const InlineTafsirSheet({
    super.key,
    required this.ayah,
    required this.pageIndex,
    this.languageCode = 'en',
  });

  static Future<void> show(
    BuildContext context, {
    required AyahModel ayah,
    required int pageIndex,
    String languageCode = 'en',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66000000),
      builder: (_) => InlineTafsirSheet(
        ayah: ayah,
        pageIndex: pageIndex,
        languageCode: languageCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<QuranCtrl>(
      builder: (ctrl) => Obx(() {
        final palette = ctrl.state.quranTheme.value.palette;
        final isDark = ctrl.state.quranTheme.value.isDark;
        // Build a TafsirStyle that pulls every customisable colour
        // from our palette. ShowTafseer reads these on render so
        // a theme cycle while the sheet is open re-skins it on
        // the next frame via the surrounding Obx.
        final defaultStyle = TafsirStyle.defaults(isDark: isDark, context: context);
        final style = defaultStyle.copyWith(
          backgroundColor: palette.surface,
          textColor: palette.ink,
        );
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Scaffold(
            // Transparent so the showModalBottomSheet barrier and
            // our sheet container colour are what the user sees.
            backgroundColor: Colors.transparent,
            body: ShowTafseer(
              ayahUQNumber: ayah.ayahUQNumber,
              ayahNumber: ayah.ayahNumber,
              pageIndex: pageIndex,
              context: context,
              isDark: isDark,
              tafsirStyle: style,
            ),
          ),
        );
      }),
    );
  }
}
