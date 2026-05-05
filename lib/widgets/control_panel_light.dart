import 'package:flutter/material.dart';

enum LightStatus { on, off, blink, alert }

class ControlPanelLight extends StatefulWidget {
  final LightStatus status;
  final Color color;
  final double size;
  final String? label;

  const ControlPanelLight({
    super.key,
    required this.status,
    this.color = const Color(0xFF00E676),
    this.size = 12,
    this.label,
  });

  @override
  State<ControlPanelLight> createState() => _ControlPanelLightState();
}

class _ControlPanelLightState extends State<ControlPanelLight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.status == LightStatus.alert
          ? const Duration(milliseconds: 400)
          : const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldAnimate =
        widget.status == LightStatus.blink || widget.status == LightStatus.alert;
    final isOn = widget.status == LightStatus.on || shouldAnimate;

    Widget dot = AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final opacity = shouldAnimate ? _anim.value : (isOn ? 1.0 : 0.18);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: opacity),
            boxShadow: isOn
                ? [BoxShadow(color: widget.color.withValues(alpha: 0.6), blurRadius: widget.size)]
                : null,
          ),
        );
      },
    );

    if (widget.label != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(width: 6),
          Text(
            widget.label!,
            style: TextStyle(
              color: widget.color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );
    }
    return dot;
  }
}
