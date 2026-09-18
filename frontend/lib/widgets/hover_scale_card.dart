import 'package:flutter/material.dart';

class HoverScaleCard extends StatefulWidget {
  final Widget child;
  const HoverScaleCard({Key? key, required this.child}) : super(key: key);

  @override
  _HoverScaleCardState createState() => _HoverScaleCardState();
}

class _HoverScaleCardState extends State<HoverScaleCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isPressed = true),
      onExit: (_) => setState(() => _isPressed = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: RepaintBoundary(child: widget.child),
        ),
      ),
    );
  }
}
