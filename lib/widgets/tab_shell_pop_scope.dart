import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import 'main_shell_back_scope.dart';

/// Same role as the legacy will-pop handler, implemented with [PopScope]: when
/// [handleShellBack] is true (this tab is visible in the bottom [IndexedStack]),
/// blocks the system back gesture and runs the same exit confirmation as the
/// Settings tab.
///
/// Inactive tabs must pass `handleShellBack: false` so they do not register a
/// competing [PopScope] while kept alive off-screen.
class TabShellPopScope extends StatelessWidget {
  const TabShellPopScope({
    super.key,
    required this.handleShellBack,
    required this.child,
  });

  final bool handleShellBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!handleShellBack) return child;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        unawaited(MainShellBackScope.delegateExitConfirmation(context));
      },
      child: child,
    );
  }
}
