import 'package:flutter/material.dart';

import '../theme/paper_tokens.dart';
import 'paper_icon.dart';

/// `PaperMenu` surface (components.md §13). Applied app-wide through
/// `ThemeData.menuTheme`; exposed for custom anchors.
const MenuStyle paperMenuStyle = PaperTheme.menuStyle;

/// Item style: radius 4, `px-3 py-1.5`, 32 tall, 14/20 500 gray-200,
/// hover/pressed/focus fill gray-800; [destructive] = red-400 / red-950.
ButtonStyle paperMenuItemStyle({bool destructive = false}) {
  final fg = destructive ? PaperWeb.red400 : PaperWeb.gray200;
  final hot = destructive ? PaperWeb.red950 : PaperWeb.gray800;
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 32)),
    maximumSize: const WidgetStatePropertyAll<Size>(Size(320, 64)),
    padding: const WidgetStatePropertyAll<EdgeInsets>(
      EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: const WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: PaperRadii.borderSm),
    ),
    overlayColor: const WidgetStatePropertyAll<Color>(Color(0x00000000)),
    splashFactory: NoSplash.splashFactory,
    textStyle: const WidgetStatePropertyAll<TextStyle>(
      TextStyle(
        fontFamily: PaperTypography.sans,
        fontFamilyFallback: PaperTypography.sansFallback,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w500,
      ),
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled) ? fg.withValues(alpha: 0.5) : fg,
    ),
    iconColor: WidgetStatePropertyAll<Color>(fg),
    backgroundColor: WidgetStateProperty.resolveWith(
      (s) =>
          s.contains(WidgetState.hovered) ||
              s.contains(WidgetState.pressed) ||
              s.contains(WidgetState.focused)
          ? hot
          : const Color(0x00000000),
    ),
  );
}

/// A `PaperMenu` item for [MenuAnchor] menus. Text only (the web never
/// puts icons in text actions); [selected] shows a trailing accent check
/// (sort / radio menus); [subtitle] is an optional second `xs gray-400`
/// line (e.g. why it is disabled).
class PaperMenuItem extends StatelessWidget {
  const PaperMenuItem({
    super.key,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.destructive = false,
    this.subtitle,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final bool destructive;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final Widget text = subtitle == null
        ? Text(label)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(label),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontFamily: PaperTypography.sans,
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w400,
                  color: PaperWeb.gray400,
                ),
              ),
            ],
          );
    return MenuItemButton(
      style: paperMenuItemStyle(destructive: destructive).copyWith(
        foregroundColor: selected
            ? const WidgetStatePropertyAll<Color>(PaperWeb.gray100)
            : null,
      ),
      onPressed: onPressed,
      trailingIcon: selected
          ? const PaperIcon(PaperIcons.check, color: PaperWeb.accent)
          : null,
      child: Semantics(selected: selected ? true : null, child: text),
    );
  }
}

/// 1px gray-800 divider with 4px vertical margin.
class PaperMenuDivider extends StatelessWidget {
  const PaperMenuDivider({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: SizedBox(height: 1, child: ColoredBox(color: PaperWeb.gray800)),
  );
}
