import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/pattern.dart';

class PatternPainter extends CustomPainter {
  const PatternPainter({
    required this.pattern,
    required this.showGrid,
    required this.showColorCodes,
    required this.selectedCells,
    required this.viewScale,
    required this.selectionColor,
  });

  final Pattern pattern;
  final bool showGrid;
  final bool showColorCodes;
  final Set<int> selectedCells;
  final double viewScale;
  final Color selectionColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / pattern.width;
    final cellHeight = size.height / pattern.height;
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;

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

    final visibleCellSize = math.min(cellWidth, cellHeight) * viewScale;
    if (showColorCodes && visibleCellSize >= 9) {
      _paintColorCodes(canvas, cellWidth, cellHeight);
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

    if (selectedCells.isNotEmpty) {
      final selectionFill = Paint()
        ..color = selectionColor.withValues(alpha: 0.24)
        ..style = PaintingStyle.fill;
      final selectionStroke = Paint()
        ..color = selectionColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / viewScale.clamp(1, 12);
      for (final index in selectedCells) {
        if (index < 0 || index >= pattern.colorIndices.length) continue;
        final x = index % pattern.width;
        final y = index ~/ pattern.width;
        final rect = Rect.fromLTWH(
          x * cellWidth,
          y * cellHeight,
          cellWidth,
          cellHeight,
        );
        canvas.drawRect(rect, selectionFill);
        canvas.drawRect(
          rect.deflate(selectionStroke.strokeWidth / 2),
          selectionStroke,
        );
      }
    }
  }

  void _paintColorCodes(Canvas canvas, double cellWidth, double cellHeight) {
    final cellSize = math.min(cellWidth, cellHeight);
    final painters = <int, TextPainter>{};
    for (var colorIndex = 0; colorIndex < pattern.colors.length; colorIndex++) {
      final beadColor = pattern.colors[colorIndex];
      var fontSize = math.max(0.8, cellSize * 0.46);
      TextPainter createPainter() => TextPainter(
        text: TextSpan(
          text: beadColor.code,
          style: TextStyle(
            color: beadColor.color.computeLuminance() > 0.42
                ? const Color(0xff151719)
                : Colors.white,
            fontSize: fontSize,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      var painter = createPainter();
      final maximumWidth = cellWidth * 0.86;
      if (painter.width > maximumWidth && painter.width > 0) {
        fontSize *= maximumWidth / painter.width;
        painter = createPainter();
      }
      painters[colorIndex] = painter;
    }

    for (var index = 0; index < pattern.colorIndices.length; index++) {
      final colorIndex = pattern.colorIndices[index];
      final painter = painters[colorIndex]!;
      final x = index % pattern.width;
      final y = index ~/ pattern.width;
      painter.paint(
        canvas,
        Offset(
          x * cellWidth + (cellWidth - painter.width) / 2,
          y * cellHeight + (cellHeight - painter.height) / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PatternPainter oldDelegate) {
    return oldDelegate.pattern != pattern ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showColorCodes != showColorCodes ||
        oldDelegate.viewScale != viewScale ||
        oldDelegate.selectionColor != selectionColor ||
        !setEquals(oldDelegate.selectedCells, selectedCells);
  }
}

class BrushStrokePainter extends CustomPainter {
  const BrushStrokePainter({
    required this.pattern,
    required this.cells,
    required this.color,
    required this.viewScale,
  });

  final Pattern pattern;
  final Set<int> cells;
  final Color color;
  final double viewScale;

  @override
  void paint(Canvas canvas, Size size) {
    if (cells.isEmpty) return;
    final cellWidth = size.width / pattern.width;
    final cellHeight = size.height / pattern.height;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 / viewScale.clamp(1, 12);
    for (final index in cells) {
      if (index < 0 || index >= pattern.colorIndices.length) continue;
      final x = index % pattern.width;
      final y = index ~/ pattern.width;
      final rect = Rect.fromLTWH(
        x * cellWidth,
        y * cellHeight,
        cellWidth,
        cellHeight,
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect.deflate(stroke.strokeWidth / 2), stroke);
    }
  }

  @override
  bool shouldRepaint(covariant BrushStrokePainter oldDelegate) {
    return oldDelegate.pattern != pattern ||
        oldDelegate.color != color ||
        oldDelegate.viewScale != viewScale ||
        !setEquals(oldDelegate.cells, cells);
  }
}
