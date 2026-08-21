import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Wraps any child with a smooth hover glow + scale response, using
/// MouseRegion (desktop/web) with a graceful no-op on touch devices where
/// hover doesn't exist. Used for buttons and list items throughout the
/// app so interactive elements feel alive rather than static.
class HoverGlow extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double hoverScale;
  final Color glowColor;

  const HoverGlow({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.hoverScale = 1.04,
    this.glowColor = AppTheme.accent,
  });

  @override
  State<HoverGlow> createState() => _HoverGlowState();
}

class _HoverGlowState extends State<HoverGlow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? widget.hoverScale : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          borderRadius: widget.borderRadius,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: widget.glowColor.withOpacity(0.45),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
