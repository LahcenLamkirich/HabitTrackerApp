import 'package:flutter/material.dart';

/// Centers [child] and caps its width on large screens (tablet/desktop/web)
/// so content doesn't stretch edge-to-edge, while behaving exactly like a
/// plain full-width child on phones.
///
/// Set [shrinkWrapHeight] to true when wrapping something that must hug its
/// own content height (a sticky footer button, a bottom nav bar) — otherwise
/// the default alignment behavior expands to fill all available height,
/// which pushes the visible content to the top of that oversized box.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool shrinkWrapHeight;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 700,
    this.shrinkWrapHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: shrinkWrapHeight ? 1 : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
