import 'package:flutter/material.dart';

/// Shared tablet / iPad sizing so lists don't stretch edge-to-edge.
abstract final class AppBreakpoints {
  static const tabletShortestSide = 600.0;
  static const contentMax = 720.0;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= tabletShortestSide;

  static double contentWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (!isTablet(context)) return width;
    return contentMax.clamp(0, width - 48);
  }

  static int gridColumns(
    BuildContext context, {
    required int phone,
    required int tablet,
  }) =>
      isTablet(context) ? tablet : phone;
}

/// Centers [child] and caps its width on iPad.
class AppContent extends StatelessWidget {
  const AppContent({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? AppBreakpoints.contentWidth(context),
        ),
        child: child,
      ),
    );
  }
}
