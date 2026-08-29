// Copyright (c) 2026 Niko Pascal Burkert. All rights reserved.
// Licensed under the Business Source License 1.1.
// See LICENSE in the project root for license information.

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/product_info.dart';
import '../../localization/desktop_strings.dart';
import '../../models/settings_models.dart';
import '../../theme/premium_white_bronze_tokens.dart';
import '../../theme/ui_chrome_config.dart';
import '../../theme/ui_surface_styles.dart';
import '../common/bronze_brush_texture.dart';
import '../common/bronze_reflection.dart';
import '../common/glass_panel.dart';

class SettingsSidebar extends StatelessWidget {
  const SettingsSidebar({
    super.key,
    required this.cornerRadius,
    required this.strings,
    required this.selectedSection,
    required this.onSelectSection,
    this.lightGlassColor,
    this.darkGlassColor,
    this.lightBorderColor,
    this.darkBorderColor,
  });

  final double cornerRadius;
  final DesktopStrings strings;
  final DesktopSettingsSection selectedSection;
  final ValueChanged<DesktopSettingsSection> onSelectSection;
  final Color? lightGlassColor;
  final Color? darkGlassColor;
  final Color? lightBorderColor;
  final Color? darkBorderColor;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color background = UiSurfaceStyles.sidebarSurface(
      context,
      lightOverride: lightGlassColor,
      darkOverride: darkGlassColor,
    );
    final Color border = UiSurfaceStyles.sidebarBorder(
      context,
      lightOverride: lightBorderColor,
      darkOverride: darkBorderColor,
    );
    final List<_SettingsSidebarItem> items = <_SettingsSidebarItem>[
      _SettingsSidebarItem(
        section: DesktopSettingsSection.general,
        icon: PhosphorIconsRegular.slidersHorizontal,
        label: strings.settingsNavGeneral,
      ),
      _SettingsSidebarItem(
        section: DesktopSettingsSection.notifications,
        icon: PhosphorIconsRegular.bell,
        label: strings.settingsNavNotifications,
      ),
      _SettingsSidebarItem(
        section: DesktopSettingsSection.automation,
        icon: PhosphorIconsRegular.robot,
        label: strings.settingsNavAutomation,
      ),
      _SettingsSidebarItem(
        section: DesktopSettingsSection.security,
        icon: PhosphorIconsRegular.shieldCheck,
        label: strings.settingsNavSecurity,
      ),
      _SettingsSidebarItem(
        section: DesktopSettingsSection.storage,
        icon: PhosphorIconsRegular.database,
        label: strings.settingsNavStorage,
      ),
    ];

    return GlassPanel(
      borderRadius: cornerRadius,
      lightColor: background,
      darkColor: background,
      lightBorderColor: border,
      darkBorderColor: border,
      child: Column(
        children: <Widget>[
          const SizedBox(height: UiChromeConfig.sidebarOuterTopPadding),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UiChromeConfig.sidebarListHorizontalPadding,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                strings.settingsSidebarTitle,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: dark
                      ? Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.90)
                      : PremiumWhiteBronzeTokens.onSurface.withValues(
                          alpha: 0.82,
                        ),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: UiChromeConfig.space8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: UiChromeConfig.sidebarListHorizontalPadding,
              ),
              itemCount: items.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: UiChromeConfig.sidebarItemGap),
              itemBuilder: (BuildContext context, int index) {
                final _SettingsSidebarItem item = items[index];
                final bool selected = item.section == selectedSection;
                return _SettingsSidebarButton(
                  item: item,
                  selected: selected,
                  darkMode: dark,
                  onPressed: () => onSelectSection(item.section),
                );
              },
            ),
          ),
          const SizedBox(height: UiChromeConfig.space8),
          _SettingsSidebarVersion(darkMode: dark),
          const SizedBox(height: UiChromeConfig.sidebarOuterBottomPadding),
        ],
      ),
    );
  }
}

/// Build identity for the running app. Without it a user filing a bug report
/// has no way to say which build they are on.
class _SettingsSidebarVersion extends StatelessWidget {
  const _SettingsSidebarVersion({required this.darkMode});

  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    final Color color = darkMode
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)
        : PremiumWhiteBronzeTokens.onSurface.withValues(alpha: 0.45);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UiChromeConfig.sidebarListHorizontalPadding,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SelectableText(
          ProductInfo.versionLine,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}

class _SettingsSidebarItem {
  const _SettingsSidebarItem({
    required this.section,
    required this.icon,
    required this.label,
  });

  final DesktopSettingsSection section;
  final IconData icon;
  final String label;
}

class _SettingsSidebarButton extends StatefulWidget {
  const _SettingsSidebarButton({
    required this.item,
    required this.selected,
    required this.darkMode,
    required this.onPressed,
  });

  final _SettingsSidebarItem item;
  final bool selected;
  final bool darkMode;
  final VoidCallback onPressed;

  @override
  State<_SettingsSidebarButton> createState() => _SettingsSidebarButtonState();
}

class _SettingsSidebarButtonState extends State<_SettingsSidebarButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant _SettingsSidebarButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected &&
        oldWidget.item.section == widget.item.section) {
      return;
    }
    _hovered = false;
    _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final bool metalActive = widget.selected;
    final double scale = !metalActive
        ? 1
        : (_pressed ? 0.992 : (_hovered ? 1.010 : 1));
    final double yOffset = !metalActive
        ? 0
        : (_pressed ? 0.75 : (_hovered ? -0.30 : 0));

    return InkWell(
      onTap: widget.onPressed,
      onHover: metalActive ? _setHovered : null,
      onHighlightChanged: metalActive ? _setPressed : null,
      borderRadius: BorderRadius.circular(UiChromeConfig.sidebarItemRadius),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 190),
        curve: Curves.easeOutCubic,
        scale: scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, yOffset, 0),
          height: UiChromeConfig.sidebarItemHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              UiChromeConfig.sidebarItemRadius,
            ),
            gradient: metalActive
                ? PremiumWhiteBronzeTokens.bronzeGradientFor(
                    widget.item.section.index + 301,
                  )
                : null,
            color: metalActive ? null : Colors.transparent,
            boxShadow: _resolvedMetalShadow(),
          ),
          child: CustomPaint(
            foregroundPainter: metalActive
                ? BronzeBrushTexturePainter(
                    seed: 500 + widget.item.section.index,
                    strength: 0.52,
                    borderRadius: UiChromeConfig.sidebarItemRadius,
                  )
                : null,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (metalActive)
                  IgnorePointer(
                    child: BronzeSpecularLight(
                      seed: widget.item.section.index + 301,
                      borderRadius: UiChromeConfig.sidebarItemRadius,
                      hovered: _hovered,
                      pressed: _pressed,
                      baseIntensity: 0.70,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UiChromeConfig.sidebarItemHorizontalPadding,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        widget.item.icon,
                        size: UiChromeConfig.sidebarItemIconSize,
                        color: widget.selected
                            ? Colors.white
                            : (widget.darkMode
                                  ? Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.86)
                                  : PremiumWhiteBronzeTokens.onSurface),
                        shadows: widget.selected
                            ? PremiumWhiteBronzeTokens.bronzeForegroundShadows
                            : null,
                      ),
                      const SizedBox(
                        width: UiChromeConfig.sidebarItemContentGap,
                      ),
                      Expanded(
                        child: Text(
                          widget.item.label,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: widget.selected
                                    ? Colors.white
                                    : (widget.darkMode
                                          ? Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.94)
                                          : PremiumWhiteBronzeTokens.onSurface),
                                fontWeight: widget.selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                shadows: widget.selected
                                    ? PremiumWhiteBronzeTokens
                                          .bronzeForegroundShadows
                                    : null,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setHovered(bool value) {
    if (_hovered == value || !mounted) {
      return;
    }
    setState(() {
      _hovered = value;
    });
  }

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) {
      return;
    }
    setState(() {
      _pressed = value;
    });
  }

  List<BoxShadow>? _resolvedMetalShadow() {
    if (!widget.selected) {
      return null;
    }

    if (_pressed) {
      return <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.14),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];
    }

    if (_hovered) {
      return <BoxShadow>[
        ...PremiumWhiteBronzeTokens.softSurfaceShadow,
        const BoxShadow(
          color: Color(0x2FA97658),
          blurRadius: 12,
          offset: Offset(0, 7),
        ),
      ];
    }

    return PremiumWhiteBronzeTokens.softSurfaceShadow;
  }
}
