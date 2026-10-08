import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Sticker-style text: a thick stroke behind the fill.
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    this.size = 28,
    this.color = Colors.white,
    this.strokeColor = Palette.ink,
    this.strokeWidth = 6,
    this.textAlign = TextAlign.center,
    this.maxLines = 1,
  });

  final String text;
  final double size;
  final Color color;
  final Color strokeColor;
  final double strokeWidth;
  final TextAlign textAlign;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final base = FunText.display(size: size);
    return Stack(
      children: [
        Text(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = strokeColor,
            color: null,
          ),
        ),
        Text(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(color: color),
        ),
      ],
    );
  }
}
