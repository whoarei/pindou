import 'package:flutter/foundation.dart';

import '../../models/bead_color.dart';
import '../../models/crop_spec.dart';
import '../../models/pattern.dart';

@immutable
class EditorState {
  const EditorState({
    this.palettes = const [],
    this.selectedBrand = 'Perler',
    this.sourceBytes,
    this.sourceName,
    this.sourceWidth,
    this.sourceHeight,
    this.crop = CropSpec.full,
    this.patternWidth = 40,
    this.patternHeight = 40,
    this.lockAspectRatio = true,
    this.maximumColors = 16,
    this.dither = false,
    this.showGrid = true,
    this.pattern,
    this.isLoadingPalettes = true,
    this.isProcessing = false,
    this.isExporting = false,
    this.errorMessage,
    this.lastExportPath,
  });

  final List<BeadPalette> palettes;
  final String selectedBrand;
  final Uint8List? sourceBytes;
  final String? sourceName;
  final int? sourceWidth;
  final int? sourceHeight;
  final CropSpec crop;
  final int patternWidth;
  final int patternHeight;
  final bool lockAspectRatio;
  final int maximumColors;
  final bool dither;
  final bool showGrid;
  final Pattern? pattern;
  final bool isLoadingPalettes;
  final bool isProcessing;
  final bool isExporting;
  final String? errorMessage;
  final String? lastExportPath;

  BeadPalette? get selectedPalette {
    for (final palette in palettes) {
      if (palette.brand == selectedBrand) return palette;
    }
    return palettes.firstOrNull;
  }

  bool get canGenerate =>
      sourceBytes != null && selectedPalette != null && !isProcessing;

  double? get croppedAspectRatio {
    if (sourceWidth == null || sourceHeight == null) return null;
    final rotated = crop.quarterTurns.isOdd;
    final width = rotated ? sourceHeight! : sourceWidth!;
    final height = rotated ? sourceWidth! : sourceHeight!;
    return (width * crop.width) / (height * crop.height);
  }

  EditorState copyWith({
    List<BeadPalette>? palettes,
    String? selectedBrand,
    Uint8List? sourceBytes,
    String? sourceName,
    int? sourceWidth,
    int? sourceHeight,
    CropSpec? crop,
    int? patternWidth,
    int? patternHeight,
    bool? lockAspectRatio,
    int? maximumColors,
    bool? dither,
    bool? showGrid,
    Pattern? pattern,
    bool clearPattern = false,
    bool? isLoadingPalettes,
    bool? isProcessing,
    bool? isExporting,
    String? errorMessage,
    bool clearError = false,
    String? lastExportPath,
  }) {
    return EditorState(
      palettes: palettes ?? this.palettes,
      selectedBrand: selectedBrand ?? this.selectedBrand,
      sourceBytes: sourceBytes ?? this.sourceBytes,
      sourceName: sourceName ?? this.sourceName,
      sourceWidth: sourceWidth ?? this.sourceWidth,
      sourceHeight: sourceHeight ?? this.sourceHeight,
      crop: crop ?? this.crop,
      patternWidth: patternWidth ?? this.patternWidth,
      patternHeight: patternHeight ?? this.patternHeight,
      lockAspectRatio: lockAspectRatio ?? this.lockAspectRatio,
      maximumColors: maximumColors ?? this.maximumColors,
      dither: dither ?? this.dither,
      showGrid: showGrid ?? this.showGrid,
      pattern: clearPattern ? null : (pattern ?? this.pattern),
      isLoadingPalettes: isLoadingPalettes ?? this.isLoadingPalettes,
      isProcessing: isProcessing ?? this.isProcessing,
      isExporting: isExporting ?? this.isExporting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastExportPath: lastExportPath ?? this.lastExportPath,
    );
  }
}
