import 'package:flutter/material.dart';

import '../feedback/fx.dart';
import '../theme/palette.dart';

/// Chunky "candy block" button: a glossy face resting on a darker lip.
/// Pressing pushes the face down into the lip, release springs it back.
class CandyButton extends StatefulWidget {
  const CandyButton({
    super.key,
    this.label,
    this.icon,
    this.child,
    this.candy = Candy.sun,
    this.onTap,
    this.height = 56,
    this.width,
    this.lip = 6,
    this.radius = 20,
    this.fontSize = 20,
    this.foreground = Palette.ink,
    this.outlined = true,
    this.sound = true,
  });

  final String? label;
  final IconData? icon;
  final Widget? child;
  final Candy candy;
  final VoidCallback? onTap;
  final double height;
  final double? width;
  final double lip;
  final double radius;
  final double fontSize;
  final Color foreground;
  final bool outlined;
  final bool sound;

  @override
  State<CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<CandyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
    reverseDuration: const Duration(milliseconds: 380),
  );

  bool get _enabled => widget.onTap != null;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Widget _content() {
    if (widget.child != null) return widget.child!;
    final style =
        FunText.title(color: widget.foreground, size: widget.fontSize);
    final icon = widget.icon == null
        ? null
        : Icon(widget.icon,
            color: widget.foreground, size: widget.fontSize * 1.25);
    if (widget.label == null) return icon ?? const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[icon, const SizedBox(width: 6)],
        Flexible(
          child: Text(
            widget.label!,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final candy = _enabled ? widget.candy : Candy.slate;
    final radius = BorderRadius.circular(widget.radius);
    final border =
        widget.outlined ? Border.all(color: Palette.ink, width: 2.5) : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _enabled ? (_) => _press.forward() : null,
      onTapCancel: _enabled ? () => _press.reverse() : null,
      onTapUp: _enabled
          ? (_) {
              _press.reverse();
              if (widget.sound) Fx.tap();
              widget.onTap!();
            }
          : null,
      child: SizedBox(
        width: widget.width,
        height: widget.height + widget.lip,
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, child) {
            final t = Curves.easeOut.transform(_press.value);
            final drop = widget.lip * t;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: widget.lip,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: candy.shade,
                      borderRadius: radius,
                      border: border,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: drop,
                  height: widget.height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: border,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [candy.light, candy.face, candy.face],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: widget.radius * 0.6,
                          right: widget.radius * 0.6,
                          top: 4,
                          height: widget.height * 0.18,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.child == null ? 14 : 0,
                            ),
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          child: _content(),
        ),
      ),
    );
  }
}

/// Round icon-only candy button used in top bars.
class CandyIconButton extends StatelessWidget {
  const CandyIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.candy = Candy.cream,
    this.size = 50,
    this.iconColor = Palette.ink,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Candy candy;
  final double size;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return CandyButton(
      width: size,
      height: size,
      lip: 5,
      radius: size / 2,
      candy: candy,
      onTap: onTap,
      child: Icon(icon, color: iconColor, size: size * 0.56),
    );
  }
}
