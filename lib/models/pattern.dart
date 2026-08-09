import 'package:flutter/foundation.dart';

import 'bead_color.dart';

@immutable
class Pattern {
  const Pattern({
    required this.width,
    required this.height,
    required this.colorIndices,
    required this.colors,
    required this.counts,
  });

  final int width;
  final int height;
  final List<int> colorIndices;
  final List<BeadColor> colors;
  final List<int> counts;

  int get totalBeads => width * height;

  List<ColorUsage> get usages {
    final values = <ColorUsage>[
      for (var i = 0; i < colors.length; i++)
        ColorUsage(color: colors[i], count: counts[i]),
    ];
    values.sort((a, b) => b.count.compareTo(a.count));
    return values;
  }
}

@immutable
class ColorUsage {
  const ColorUsage({required this.color, required this.count});

  final BeadColor color;
  final int count;
}
