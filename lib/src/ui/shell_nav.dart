import 'package:flutter/material.dart';

/// Lets child tabs (Dashboard) jump to Home / Settings without rebuilding nav.
class ShellNav extends InheritedWidget {
  const ShellNav({
    super.key,
    required this.index,
    required this.goTo,
    required super.child,
  });

  final int index;
  final ValueChanged<int> goTo;

  static ShellNav? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellNav>();
  }

  static ShellNav of(BuildContext context) {
    final nav = maybeOf(context);
    assert(nav != null, 'ShellNav not found');
    return nav!;
  }

  @override
  bool updateShouldNotify(ShellNav oldWidget) => index != oldWidget.index;
}
