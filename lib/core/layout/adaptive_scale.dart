import 'package:flutter/widgets.dart';

/// Scales the whole UI up on large screens (tablets, desktop windows).
///
/// Phone layouts are designed around a ~480dp short side. On bigger screens
/// the child is laid out in a proportionally smaller logical viewport and
/// then magnified, so every board, button and text grows together while the
/// layout code keeps seeing phone-like dimensions.
class AdaptiveScale extends StatelessWidget {
  const AdaptiveScale({super.key, required this.child});

  final Widget child;

  static const double _baseShortSide = 480;
  static const double _maxScale = 1.7;

  static double scaleFor(Size size) =>
      (size.shortestSide / _baseShortSide).clamp(1.0, _maxScale);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = scaleFor(media.size);
    if (scale <= 1.001) return child;
    final logical = Size(media.size.width / scale, media.size.height / scale);
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox.fromSize(
        size: logical,
        child: MediaQuery(
          data: media.copyWith(
            size: logical,
            padding: media.padding / scale,
            viewPadding: media.viewPadding / scale,
            viewInsets: media.viewInsets / scale,
            systemGestureInsets: media.systemGestureInsets / scale,
          ),
          child: child,
        ),
      ),
    );
  }
}
