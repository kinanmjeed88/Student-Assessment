import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Enables mouse and touchpad drag scrolling for Windows desktop pages.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
