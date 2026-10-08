import 'package:flutter/widgets.dart';

/// True for wide landscape viewports (tablets, desktop windows) where game
/// pages put their controls in a side panel next to the board.
bool isWideLandscape(Size size) =>
    size.width >= 620 && size.width > size.height * 1.2;

/// Tells header / footer widgets that they are laid out inside the vertical
/// side panel of a wide landscape game page, so they can stack vertically.
class SidePanelScope extends InheritedWidget {
  const SidePanelScope({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SidePanelScope>() != null;

  @override
  bool updateShouldNotify(SidePanelScope oldWidget) => false;
}
