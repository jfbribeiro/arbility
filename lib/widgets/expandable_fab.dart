import 'package:flutter/material.dart';

/// Describes a single action available in the [ExpandableFab] menu.
class FabAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const FabAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

/// A Material-style FAB that expands into a vertical list of [FabAction]
/// items when tapped. The main button rotates to indicate the open state.
class ExpandableFab extends StatefulWidget {
  final List<FabAction> actions;

  const ExpandableFab({super.key, required this.actions});

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Toggles the expanded/collapsed state and drives the animation.
  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 250,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Action items
          SizeTransition(
            sizeFactor: _expandAnimation,
            axisAlignment: 1.0,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: widget.actions.map((action) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _FabActionItem(
                      icon: action.icon,
                      label: action.label,
                      onPressed: () {
                        _toggle();
                        action.onPressed();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Main FAB
          FloatingActionButton(
            onPressed: _toggle,
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            child: AnimatedRotation(
              turns: _isOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.add, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _FabActionItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _FabActionItem({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_FabActionItem> createState() => _FabActionItemState();
}

class _FabActionItemState extends State<_FabActionItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _hovering
                    ? colors.primary.withValues(alpha: 0.1)
                    : colors.surface,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Icon circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _hovering
                    ? colors.primary
                    : colors.primary.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
