import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Rounded cream panel with an ink outline and a soft lip, the base surface
/// for sheets, dialogs and info boxes.
class CandyPanel extends StatelessWidget {
  const CandyPanel({
    super.key,
    required this.child,
    this.candy = Candy.cream,
    this.padding = const EdgeInsets.all(16),
    this.radius = 28,
    this.lip = 6,
    this.outline = 3,
  });

  final Widget child;
  final Candy candy;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double lip;
  final double outline;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: candy.face,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Palette.ink, width: outline),
        boxShadow: [
          BoxShadow(color: candy.shade, offset: Offset(0, lip)),
          BoxShadow(color: Palette.ink, offset: Offset(0, lip + outline * 0.6)),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

/// A small rounded label chip.
class CandyChip extends StatelessWidget {
  const CandyChip({
    super.key,
    required this.label,
    this.candy = Candy.cream,
    this.icon,
    this.fontSize = 13,
  });

  final String label;
  final Candy candy;
  final Widget? icon;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: fontSize * 0.7, vertical: fontSize * 0.25),
      decoration: BoxDecoration(
        color: candy.face,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Palette.ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 4)],
          Text(label,
              style: FunText.caption(color: Palette.ink, size: fontSize)),
        ],
      ),
    );
  }
}
