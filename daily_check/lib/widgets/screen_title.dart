import 'package:flutter/material.dart';

/// A consistent, animated page heading used across the top-level screens:
/// a colored icon badge, a bold title, and an optional subtitle — replacing
/// plain `Text` headers with something that feels designed and alive.
///
/// Fades and slides down into place once when the screen first builds.
class ScreenTitle extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const ScreenTitle({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  State<ScreenTitle> createState() => _ScreenTitleState();
}

class _ScreenTitleState extends State<ScreenTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    final slide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(fade);

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.color, widget.color.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.onSurface,
                        widget.color,
                      ],
                    ).createShader(bounds),
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                    ),
                  ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      ),
    );
  }
}
