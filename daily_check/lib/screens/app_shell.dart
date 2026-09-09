import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add_edit_task_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'streaks_screen.dart';
import 'today_screen.dart';
import '../widgets/responsive_center.dart';

/// The bottom-navigation shell that hosts the four top-level screens.
///
/// Floating white dock with rounded 32px corners, soft top shadow, and
/// a coral gradient FAB notch in the center — matches Stitch design.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _screens = [
    TodayScreen(),
    StreaksScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  void _openAdd() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddEditTaskScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mindful Habit Track tokens
    const primary = Color(0xFFE85D30);
    const secondary = Color(0xFFFF8A65);
    const textHigh = Color(0xFF1F2429);
    const inactive = Color(0xFF9CA3AF);

    return Scaffold(
      body: ResponsiveCenter(
        child: IndexedStack(
          index: _index,
          children: _screens,
        ),
      ),
      bottomNavigationBar: ResponsiveCenter(
        maxWidth: 480,
        shrinkWrapHeight: true,
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1F2429).withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: 'Home',
                      isSelected: _index == 0,
                      onTap: () => setState(() => _index = 0),
                      selectedColor: primary,
                      inactiveColor: inactive,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.local_fire_department_outlined,
                      selectedIcon: Icons.local_fire_department_rounded,
                      label: 'Streaks',
                      isSelected: _index == 1,
                      onTap: () => setState(() => _index = 1),
                      selectedColor: primary,
                      inactiveColor: inactive,
                    ),
                  ),
                  // Spacer for FAB notch
                  const SizedBox(width: 48),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.bar_chart_outlined,
                      selectedIcon: Icons.bar_chart_rounded,
                      label: 'Analytics',
                      isSelected: _index == 2,
                      onTap: () => setState(() => _index = 2),
                      selectedColor: primary,
                      inactiveColor: inactive,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.person_outline,
                      selectedIcon: Icons.person_rounded,
                      label: 'Profile',
                      isSelected: _index == 3,
                      onTap: () => setState(() => _index = 3),
                      selectedColor: primary,
                      inactiveColor: inactive,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [secondary, primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _openAdd,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          child: const Icon(Icons.add, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color inactiveColor;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.selectedColor,
    required this.inactiveColor,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    if (widget.isSelected) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant _NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _bounce,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isSelected ? _bounce.value : 1.0,
                child: child,
              );
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                widget.isSelected ? widget.selectedIcon : widget.icon,
                key: ValueKey(widget.isSelected),
                color: widget.isSelected ? widget.selectedColor : widget.inactiveColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
              color: widget.isSelected ? widget.selectedColor : widget.inactiveColor,
              letterSpacing: 0.3,
            ),
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: 4,
            width: widget.isSelected ? 4 : 0,
            decoration: BoxDecoration(
              color: widget.selectedColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
