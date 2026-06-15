part of '/quran.dart';

/// Settings tab inside the [QuranHubSheet]. Four sections, top to
/// bottom in order of frequency of use:
///
///   1. **Reader theme** — Light / Dark / Sepia segmented control.
///      Reuses `QuranCtrl.setQuranTheme` so it stays in sync with
///      the top-bar quick-cycle button.
///   2. **Tajweed colouring** — boolean toggle. Writes back to
///      `state.isTajweedEnabled` AND persists via the legacy
///      `_StorageConstants.isTajweed` key so a re-init reads it.
///   3. **Display mode** — horizontal chip strip of available
///      modes, filtered by `getAvailableModes(context)` so we
///      don't offer landscape-only modes on portrait phones.
///   4. **Font size** — a small slider over `state.scaleFactor`.
///      Clamped 0.7 → 1.6; the QuranCtrl already enforces this.
///
/// Every row reads through `Obx` so a change from anywhere else
/// (top-bar quick-cycle, pinch-to-zoom) reflects here immediately.
class QuranHubSettingsPanel extends StatelessWidget {
  final QuranThemePalette palette;
  final String languageCode;

  const QuranHubSettingsPanel({
    super.key,
    required this.palette,
    required this.languageCode,
  });

  bool get _isAr => languageCode == 'ar';

  @override
  Widget build(BuildContext context) {
    final ctrl = QuranCtrl.instance;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _SectionLabel(
          text: _isAr ? 'السمة' : 'Reader theme',
          palette: palette,
        ),
        const SizedBox(height: 8),
        Obx(() => _ThemePicker(
              palette: palette,
              isAr: _isAr,
              active: ctrl.state.quranTheme.value,
              onSelect: ctrl.setQuranTheme,
            )),
        const SizedBox(height: 20),

        _SectionLabel(
          text: _isAr ? 'التجويد' : 'Tajweed',
          palette: palette,
        ),
        const SizedBox(height: 8),
        Obx(() => _SettingsRow(
              palette: palette,
              icon: Icons.brush_rounded,
              title: _isAr ? 'تلوين التجويد' : 'Colour tajweed glyphs',
              subtitle: _isAr
                  ? 'يبرز أحكام التلاوة بألوان مميزة'
                  : 'Highlights recitation rules in colour',
              trailing: Switch.adaptive(
                value: ctrl.state.isTajweedEnabled.value,
                activeThumbColor: palette.accent,
                onChanged: (v) {
                  ctrl.state.isTajweedEnabled.value = v;
                  GetStorage().write(_StorageConstants().isTajweed, v);
                  // Same channels the legacy chrome triggers — keeps
                  // every page in sync without a hot-reload feel.
                  // ignore: invalid_use_of_protected_member
                  ctrl.update(['fonts', '_pageViewBuild']);
                },
              ),
            )),
        const SizedBox(height: 20),

        _SectionLabel(
          text: _isAr ? 'وضع العرض' : 'Display mode',
          palette: palette,
        ),
        const SizedBox(height: 8),
        Obx(() => _DisplayModeChips(
              palette: palette,
              isAr: _isAr,
              current: ctrl.state.displayMode.value,
              available: ctrl.getAvailableModes(context),
              onSelect: ctrl.setDisplayMode,
            )),
        const SizedBox(height: 20),

        _SectionLabel(
          text: _isAr ? 'حجم الخط' : 'Font size',
          palette: palette,
        ),
        const SizedBox(height: 4),
        Obx(() => _FontSizeSlider(
              palette: palette,
              isAr: _isAr,
              value: ctrl.state.scaleFactor.value,
              onChanged: (v) => ctrl.state.scaleFactor.value = v,
            )),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final QuranThemePalette palette;

  const _SectionLabel({required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: palette.subInk,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final QuranThemePalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsRow({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          palette.accent.withValues(alpha: 0.05), palette.surface),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                  palette.accent.withValues(alpha: 0.12), palette.surface),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: palette.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                      letterSpacing: -0.1,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.subInk,
                      height: 1.35,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }
}

/// Segmented control for the Quran-only theme — Light / Dark / Sepia.
/// Mirrors a Material 3 segmented button visually but uses three
/// pill-shaped cards so the active item can have its full palette
/// (background tint + icon + label) preview the chosen mode.
class _ThemePicker extends StatelessWidget {
  final QuranThemePalette palette;
  final bool isAr;
  final QuranThemeMode active;
  final ValueChanged<QuranThemeMode> onSelect;

  const _ThemePicker({
    required this.palette,
    required this.isAr,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final mode in QuranThemeMode.values) ...[
          Expanded(
            child: _ThemePickerOption(
              chromePalette: palette,
              preview: mode.palette,
              isActive: mode == active,
              label: _label(mode),
              icon: _iconFor(mode),
              onTap: () => onSelect(mode),
            ),
          ),
          if (mode != QuranThemeMode.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  String _label(QuranThemeMode mode) {
    if (isAr) {
      return switch (mode) {
        QuranThemeMode.light => 'فاتح',
        QuranThemeMode.dark  => 'داكن',
        QuranThemeMode.sepia => 'بُني',
      };
    }
    return switch (mode) {
      QuranThemeMode.light => 'Light',
      QuranThemeMode.dark  => 'Dark',
      QuranThemeMode.sepia => 'Sepia',
    };
  }

  IconData _iconFor(QuranThemeMode mode) => switch (mode) {
        QuranThemeMode.light => Icons.light_mode_rounded,
        QuranThemeMode.dark  => Icons.dark_mode_rounded,
        QuranThemeMode.sepia => Icons.local_cafe_rounded,
      };
}

class _ThemePickerOption extends StatelessWidget {
  /// Palette of the Hub itself — drives the active-border accent.
  final QuranThemePalette chromePalette;

  /// The palette this option *would* apply if selected — drives
  /// the per-option preview (background + ink colour).
  final QuranThemePalette preview;
  final bool isActive;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ThemePickerOption({
    required this.chromePalette,
    required this.preview,
    required this.isActive,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isActive ? chromePalette.accent : chromePalette.divider;
    final borderWidth = isActive ? 2.0 : 1.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: preview.pageBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: preview.ink, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: preview.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisplayModeChips extends StatelessWidget {
  final QuranThemePalette palette;
  final bool isAr;
  final QuranDisplayMode current;
  final List<QuranDisplayMode> available;
  final ValueChanged<QuranDisplayMode> onSelect;

  const _DisplayModeChips({
    required this.palette,
    required this.isAr,
    required this.current,
    required this.available,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final mode in available) ...[
            _ModeChip(
              palette: palette,
              icon: mode.icon,
              label: isAr ? mode.labelAr : mode.labelEn,
              isActive: mode == current,
              onTap: () => onSelect(mode),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final QuranThemePalette palette;
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeChip({
    required this.palette,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isActive
        ? Color.alphaBlend(palette.accent.withValues(alpha: 0.12), palette.surface)
        : Colors.transparent;
    final fg = isActive ? palette.accent : palette.subInk;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isActive ? palette.accent : palette.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                )),
          ],
        ),
      ),
    );
  }
}

class _FontSizeSlider extends StatelessWidget {
  final QuranThemePalette palette;
  final bool isAr;
  final double value;
  final ValueChanged<double> onChanged;

  const _FontSizeSlider({
    required this.palette,
    required this.isAr,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Bookend marks — A small / A big — give the slider an obvious
    // direction without a numeric value the user has no calibration
    // for.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('Aا',
                style: TextStyle(
                  fontSize: 12,
                  color: palette.subInk,
                  fontWeight: FontWeight.w700,
                )),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: palette.accent,
                  inactiveTrackColor: palette.divider,
                  thumbColor: palette.accent,
                  overlayColor: palette.accent.withValues(alpha: 0.16),
                  trackHeight: 3,
                ),
                child: Slider(
                  min: 0.7,
                  max: 1.6,
                  value: value.clamp(0.7, 1.6),
                  onChanged: onChanged,
                ),
              ),
            ),
            Text('Aا',
                style: TextStyle(
                  fontSize: 22,
                  color: palette.subInk,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          isAr
              ? 'يمكنك أيضًا التكبير بإصبعين على الصفحة'
              : 'You can also pinch-to-zoom on the page',
          style: TextStyle(
            fontSize: 11.5,
            color: palette.subInk,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

