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

  Pattern replaceCells(Iterable<int> cells, BeadColor replacement) {
    final selected = cells
        .where((index) => index >= 0 && index < colorIndices.length)
        .toSet();
    if (selected.isEmpty) return this;
    final changesAnyCell = selected.any(
      (cell) => colors[colorIndices[cell]].code != replacement.code,
    );
    if (!changesAnyCell) return this;

    final expandedColors = List<BeadColor>.of(colors);
    var replacementIndex = expandedColors.indexWhere(
      (color) => color.code == replacement.code,
    );
    if (replacementIndex < 0) {
      replacementIndex = expandedColors.length;
      expandedColors.add(replacement);
    }

    final expandedIndices = List<int>.of(colorIndices);
    for (final cell in selected) {
      expandedIndices[cell] = replacementIndex;
    }

    final expandedCounts = List<int>.filled(expandedColors.length, 0);
    for (final index in expandedIndices) {
      expandedCounts[index]++;
    }
    final remap = List<int>.filled(expandedColors.length, -1);
    final compactColors = <BeadColor>[];
    final compactCounts = <int>[];
    for (var i = 0; i < expandedColors.length; i++) {
      if (expandedCounts[i] == 0) continue;
      remap[i] = compactColors.length;
      compactColors.add(expandedColors[i]);
      compactCounts.add(expandedCounts[i]);
    }

    return Pattern(
      width: width,
      height: height,
      colorIndices: [for (final index in expandedIndices) remap[index]],
      colors: List.unmodifiable(compactColors),
      counts: List.unmodifiable(compactCounts),
    );
  }
}

@immutable
class ColorUsage {
  const ColorUsage({required this.color, required this.count});

  final BeadColor color;
  final int count;
}
