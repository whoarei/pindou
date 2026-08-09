import 'package:flutter/foundation.dart';

import '../../models/bead_color.dart';
import '../../models/crop_spec.dart';
import '../../models/pattern.dart';

enum EditorTool { pan, select, brush }

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
    this.showColorCodes = true,
    this.editTool = EditorTool.pan,
    this.brushColorCode,
    this.selectedCells = const <int>{},
    this.pattern,
    this.canUndo = false,
    this.canRedo = false,
    this.isLoadingPalettes = true,
    this.isProcessing = false,
    this.isExporting = false,
    this.errorMessage,
    this.noticeMessage,
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
  final bool showColorCodes;
  final EditorTool editTool;
  final String? brushColorCode;
  final Set<int> selectedCells;
  final Pattern? pattern;
  final bool canUndo;
  final bool canRedo;
  final bool isLoadingPalettes;
  final bool isProcessing;
  final bool isExporting;
  final String? errorMessage;
  final String? noticeMessage;
  final String? lastExportPath;

  BeadPalette? get selectedPalette {
    for (final palette in palettes) {
      if (palette.brand == selectedBrand) return palette;
    }
    return palettes.firstOrNull;
  }

  bool get canGenerate =>
      sourceBytes != null && selectedPalette != null && !isProcessing;

  bool get isColorEditing => editTool != EditorTool.pan;

  BeadColor? get selectedBrushColor {
    final palette = selectedPalette;
    if (palette == null) return null;
    for (final color in palette.colors) {
      if (color.code == brushColorCode) return color;
    }
    return palette.colors.firstOrNull;
  }

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
    bool? showColorCodes,
    EditorTool? editTool,
    String? brushColorCode,
    Set<int>? selectedCells,
    bool clearSelection = false,
    Pattern? pattern,
    bool clearPattern = false,
    bool? canUndo,
    bool? canRedo,
    bool? isLoadingPalettes,
    bool? isProcessing,
    bool? isExporting,
    String? errorMessage,
    bool clearError = false,
    String? noticeMessage,
    bool clearNotice = false,
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
      showColorCodes: showColorCodes ?? this.showColorCodes,
      editTool: clearPattern ? EditorTool.pan : (editTool ?? this.editTool),
      brushColorCode: brushColorCode ?? this.brushColorCode,
      selectedCells: Set<int>.unmodifiable(
        clearPattern || clearSelection || editTool == EditorTool.brush
            ? const <int>{}
            : (selectedCells ?? this.selectedCells),
      ),
      pattern: clearPattern ? null : (pattern ?? this.pattern),
      canUndo: clearPattern ? false : (canUndo ?? this.canUndo),
      canRedo: clearPattern ? false : (canRedo ?? this.canRedo),
      isLoadingPalettes: isLoadingPalettes ?? this.isLoadingPalettes,
      isProcessing: isProcessing ?? this.isProcessing,
      isExporting: isExporting ?? this.isExporting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      noticeMessage: clearNotice ? null : (noticeMessage ?? this.noticeMessage),
      lastExportPath: lastExportPath ?? this.lastExportPath,
    );
  }
}
