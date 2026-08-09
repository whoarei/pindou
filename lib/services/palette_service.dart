import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/bead_color.dart';

class PaletteService {
  const PaletteService();

  static const _assets = <String>[
    'assets/palettes/perler.json',
    'assets/palettes/hama.json',
    'assets/palettes/artkal.json',
  ];

  Future<List<BeadPalette>> loadPalettes() async {
    final palettes = <BeadPalette>[];
    for (final path in _assets) {
      final source = await rootBundle.loadString(path);
      palettes.add(
        BeadPalette.fromJson(jsonDecode(source) as Map<String, dynamic>),
      );
    }
    return palettes;
  }
}
