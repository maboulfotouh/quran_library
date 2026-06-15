part of '/quran.dart';

/// Settings tab inside the [QuranHubSheet]:
///   - Reader theme (Light / Dark / Sepia)
///   - Tajweed colouring toggle
///   - Display mode (default / scrollable / dual-page / +tafsir)
///   - Font size (a small slider)
///
/// Slice 3 wires each row to the corresponding QuranCtrl state
/// field; this slice is the placeholder.
class QuranHubSettingsPanel extends StatelessWidget {
  final QuranThemePalette palette;
  final String languageCode;

  const QuranHubSettingsPanel({
    super.key,
    required this.palette,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    return _PanelPlaceholder(
      palette: palette,
      message: languageCode == 'ar'
          ? 'الإعدادات: السمة، التجويد، عرض الصفحات، حجم الخط'
          : 'Settings: theme, tajweed, display mode, font size',
    );
  }
}

/// Shared empty-state widget for the slice-2 panel stubs. Keeps the
/// Hub looking coherent before the real content lands in slice 3.
class _PanelPlaceholder extends StatelessWidget {
  final QuranThemePalette palette;
  final String message;

  const _PanelPlaceholder({required this.palette, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.subInk,
            fontSize: 14,
            height: 1.5,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}
