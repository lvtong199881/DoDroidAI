import 'package:flutter/material.dart';

/// 录音波形弹窗：底部、全宽、高 40%，心电图风格（对齐原生 VoiceInputDialog + WaveformView）
class VoiceInputOverlay {
  VoiceInputOverlay._();

  static OverlayEntry? _entry;
  static final ValueNotifier<List<double>> _amplitudes =
      ValueNotifier<List<double>>(<double>[]);

  static void show(BuildContext context) {
    if (_entry != null) return;
    _amplitudes.value = <double>[];
    final overlay = Overlay.of(context, rootOverlay: true);
    final screenHeight = MediaQuery.of(context).size.height;
    _entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Material(
          color: Colors.transparent,
          child: Container(
            height: screenHeight * 0.4,
            color: const Color(0xFF1F1F1F),
            child: ValueListenableBuilder<List<double>>(
              valueListenable: _amplitudes,
              builder: (context, values, _) => CustomPaint(
                painter: _WaveformPainter(amplitudes: values),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
  }

  static void update(double normalizedAmplitude) {
    final list = List<double>.from(_amplitudes.value)
      ..add(normalizedAmplitude.clamp(0.0, 1.0));
    if (list.length > 150) {
      list.removeRange(0, list.length - 150);
    }
    _amplitudes.value = list;
  }

  static void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}

/// 心电图折线 + 网格 + 发光
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.amplitudes});

  final List<double> amplitudes;

  static const _lineColor = Color(0xFF4CAF50);
  static const _glowColor = Color(0x204CAF50);
  static const _gridColor = Color(0x1AFFFFFF);
  static const _spacing = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    if (amplitudes.length < 2) return;

    final centerY = size.height / 2;
    final scale = size.height * 0.35;
    final startX = (size.width - (amplitudes.length - 1) * _spacing) / 2;

    final path = Path();
    for (var i = 0; i < amplitudes.length; i++) {
      final x = startX + i * _spacing;
      final y = centerY - amplitudes[i] * scale;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _glowColor;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _lineColor;

    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _gridColor;
    for (var i = 1; i <= 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (var i = 1; i <= 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.amplitudes.length != amplitudes.length;
}
