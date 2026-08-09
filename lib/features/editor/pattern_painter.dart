import 'package:flutter/material.dart';

import '../../models/pattern.dart';

class PatternPainter extends CustomPainter {
  const PatternPainter({required this.pattern, required this.showGrid});

  final Pattern pattern;
  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / pattern.width;
    final cellHeight = size.height / pattern.height;
    final fillPaint = Paint()..style = PaintingStyle.fill;

    for (var y = 0; y < pattern.height; y++) {
      for (var x = 0; x < pattern.width; x++) {
        final index = pattern.colorIndices[y * pattern.width + x];
        fillPaint.color = pattern.colors[index].color;
        final rect = Rect.fromLTWH(
          x * cellWidth,
          y * cellHeight,
          cellWidth + 0.15,
          cellHeight + 0.15,
        );
        canvas.drawRect(rect, fillPaint);
        if (cellWidth >= 9 && cellHeight >= 9) {
          final highlight = Paint()
            ..color = Colors.white.withValues(alpha: 0.16)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
            Offset(
              rect.center.dx - cellWidth * 0.13,
              rect.center.dy - cellHeight * 0.13,
            ),
            cellWidth * 0.12,
            highlight,
          );
        }
      }
    }

    if (showGrid && cellWidth >= 2.5 && cellHeight >= 2.5) {
      final gridPaint = Paint()
        ..color = Colors.black.withValues(alpha: cellWidth >= 8 ? 0.38 : 0.22)
        ..strokeWidth = cellWidth >= 8 ? 0.8 : 0.45;
      for (var x = 0; x <= pattern.width; x++) {
        final dx = x * cellWidth;
        canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
      }
      for (var y = 0; y <= pattern.height; y++) {
        final dy = y * cellHeight;
        canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PatternPainter oldDelegate) {
    return oldDelegate.pattern != pattern || oldDelegate.showGrid != showGrid;
  }
}
