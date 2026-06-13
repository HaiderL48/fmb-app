import 'package:flutter/widgets.dart';

/// Provides the main shell’s “confirm exit” action so tabs (e.g. Profile) can
/// delegate system back when they are at their own root but still inside [HomePage].
class MainShellBackScope extends InheritedWidget {
  const MainShellBackScope({
    super.key,
    required this.confirmExit,
    required super.child,
  });

  final Future<void> Function() confirmExit;

  static MainShellBackScope? _maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainShellBackScope>();

  /// Runs the same exit flow as hardware back on Home / Packages / etc.
  static Future<void> delegateExitConfirmation(BuildContext context) async {
    await _maybeOf(context)?.confirmExit();
  }

  @override
  bool updateShouldNotify(MainShellBackScope oldWidget) =>
      confirmExit != oldWidget.confirmExit;
}
