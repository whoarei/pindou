import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../engine/bead_engine.dart';
import '../../models/crop_spec.dart';
import '../../services/palette_service.dart';
import 'editor_state.dart';

final editorProvider = StateNotifierProvider<EditorController, EditorState>((
  ref,
) {
  return EditorController(const PaletteService())..initialize();
});

class EditorController extends StateNotifier<EditorState> {
  EditorController(this._paletteService) : super(const EditorState());

  final PaletteService _paletteService;
  static const _filesChannel = MethodChannel('com.pindou.studio/files');

  Future<void> initialize() async {
    try {
      final palettes = await _paletteService.loadPalettes();
      if (!mounted) return;
      state = state.copyWith(
        palettes: palettes,
        isLoadingPalettes: false,
        maximumColors: 16.clamp(1, palettes.first.colors.length),
        clearError: true,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingPalettes: false,
        errorMessage: '色库加载失败：$error',
      );
    }
  }

  Future<void> pickImage() async {
    try {
      if (Platform.isWindows) {
        final selectedPath = await _filesChannel.invokeMethod<String>(
          'pickImage',
        );
        if (selectedPath == null) return;
        final bytes = await File(selectedPath).readAsBytes();
        await loadImage(bytes, p.basename(selectedPath));
      } else if (Platform.isAndroid) {
        final selected = await _filesChannel.invokeMapMethod<String, dynamic>(
          'pickImage',
        );
        if (selected == null) return;
        final bytes = selected['bytes'] as Uint8List?;
        final name = selected['name'] as String?;
        if (bytes == null) {
          throw const FormatException('未能读取所选文件。');
        }
        await loadImage(bytes, name ?? 'image.jpg');
      } else {
        throw UnsupportedError('当前平台暂未适配图片选择。');
      }
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: '导入失败：$error');
    }
  }

  Future<void> loadImage(Uint8List bytes, String name) async {
    state = state.copyWith(clearError: true);
    final dimensions = await Isolate.run(() {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw const FormatException('图片格式无效或文件已损坏。');
      }
      final oriented = img.bakeOrientation(decoded);
      return (oriented.width, oriented.height);
    });
    if (!mounted) return;
    final aspect = dimensions.$1 / dimensions.$2;
    state = state.copyWith(
      sourceBytes: bytes,
      sourceName: name,
      sourceWidth: dimensions.$1,
      sourceHeight: dimensions.$2,
      crop: CropSpec.full,
      patternWidth: 40,
      patternHeight: (40 / aspect).round().clamp(8, 200),
      clearPattern: true,
      clearError: true,
    );
  }

  void applyCrop(CropSpec crop) {
    final updated = state.copyWith(crop: crop);
    state = updated.copyWith(
      patternHeight: updated.lockAspectRatio
          ? _heightForWidth(updated.patternWidth, updated)
          : updated.patternHeight,
      clearPattern: true,
      clearError: true,
    );
  }

  void setPatternWidth(int value) {
    final width = value.clamp(8, 200);
    state = state.copyWith(
      patternWidth: width,
      patternHeight: state.lockAspectRatio
          ? _heightForWidth(width, state)
          : state.patternHeight,
      clearPattern: true,
    );
  }

  void setPatternHeight(int value) {
    final height = value.clamp(8, 200);
    state = state.copyWith(
      patternHeight: height,
      patternWidth: state.lockAspectRatio
          ? _widthForHeight(height, state)
          : state.patternWidth,
      clearPattern: true,
    );
  }

  void setAspectRatioLocked(bool value) {
    state = state.copyWith(
      lockAspectRatio: value,
      patternHeight: value
          ? _heightForWidth(state.patternWidth, state)
          : state.patternHeight,
      clearPattern: true,
    );
  }

  void setBrand(String brand) {
    final palette = state.palettes.where((item) => item.brand == brand).first;
    state = state.copyWith(
      selectedBrand: brand,
      maximumColors: state.maximumColors.clamp(1, palette.colors.length),
      clearPattern: true,
    );
  }

  void setMaximumColors(int value) {
    final maximum = state.selectedPalette?.colors.length ?? 32;
    state = state.copyWith(
      maximumColors: value.clamp(1, maximum),
      clearPattern: true,
    );
  }

  void setDither(bool value) {
    state = state.copyWith(dither: value, clearPattern: true);
  }

  void setShowGrid(bool value) {
    state = state.copyWith(showGrid: value);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> generate() async {
    final bytes = state.sourceBytes;
    final palette = state.selectedPalette;
    if (bytes == null || palette == null || state.isProcessing) return;

    state = state.copyWith(
      isProcessing: true,
      clearPattern: true,
      clearError: true,
    );
    final request = BeadEngineInput(
      bytes: bytes,
      targetWidth: state.patternWidth,
      targetHeight: state.patternHeight,
      palette: palette,
      maximumColors: state.maximumColors,
      dither: state.dither,
      crop: state.crop,
    );
    try {
      final pattern = await Isolate.run(() => generatePattern(request));
      if (!mounted) return;
      state = state.copyWith(pattern: pattern, isProcessing: false);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(isProcessing: false, errorMessage: '生成失败：$error');
    }
  }

  Future<String?> exportJpeg() async {
    final pattern = state.pattern;
    if (pattern == null || state.isExporting) return null;
    state = state.copyWith(isExporting: true, clearError: true);
    try {
      final showGrid = state.showGrid;
      final bytes = await Isolate.run(
        () => renderPatternJpeg(pattern, showGrid: showGrid),
      );
      final baseName = p.basenameWithoutExtension(
        state.sourceName ?? 'pattern',
      );
      final safeName = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName = '${safeName}_拼豆图.jpg';
      final String? savedPath;
      if (Platform.isAndroid) {
        savedPath = await _filesChannel.invokeMethod<String>(
          'saveJpeg',
          <String, Object>{'bytes': bytes, 'fileName': fileName},
        );
      } else if (Platform.isWindows) {
        final location = await _filesChannel.invokeMethod<String>(
          'pickJpegSavePath',
          <String, Object>{'fileName': fileName},
        );
        if (location == null) {
          savedPath = null;
        } else {
          await File(location).writeAsBytes(bytes, flush: true);
          savedPath = location;
        }
      } else {
        throw UnsupportedError('当前平台暂未适配 JPG 导出。');
      }
      if (!mounted) return savedPath;
      state = state.copyWith(isExporting: false, lastExportPath: savedPath);
      return savedPath;
    } catch (error) {
      if (!mounted) return null;
      state = state.copyWith(isExporting: false, errorMessage: '导出失败：$error');
      return null;
    }
  }

  int _heightForWidth(int width, EditorState source) {
    final aspect = source.croppedAspectRatio;
    if (aspect == null || aspect <= 0) return source.patternHeight;
    return (width / aspect).round().clamp(8, 200);
  }

  int _widthForHeight(int height, EditorState source) {
    final aspect = source.croppedAspectRatio;
    if (aspect == null || aspect <= 0) return source.patternWidth;
    return (height * aspect).round().clamp(8, 200);
  }
}
