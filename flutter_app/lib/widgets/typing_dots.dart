import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 三个跳动的圆点，用于 "正在输入" 状态
class TypingDots extends StatefulWidget {
  const TypingDots({
    super.key,
    this.color,
    this.dotSize = 6,
    this.spacing = 4,
  });

  final Color? color;
  final double dotSize;
  final double spacing;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              // 每个点相位错开，形成波浪式跳动
              final phase = (_controller.value - index * 0.18) % 1.0;
              final wave = (math.sin(phase * 2 * math.pi) + 1) / 2;
              final lift = 3.0 * wave;
              final opacity = 0.35 + 0.55 * wave;
              return Padding(
                padding: EdgeInsets.only(
                  right: index == 2 ? 0 : widget.spacing,
                ),
                child: Transform.translate(
                  offset: Offset(0, -lift),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: widget.dotSize,
                      height: widget.dotSize,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
