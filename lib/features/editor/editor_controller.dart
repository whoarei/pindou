import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../engine/bead_engine.dart';
import '../../models/bead_color.dart';
import '../../models/crop_spec.dart';
import '../../services/palette_service.dart';
import '../../services/project_codec.dart';
import 'editor_state.dart';

final editorProvider = StateNotifierProvider<EditorController, EditorState>((
  ref,
) {
  return EditorController(const PaletteService())..initialize();
});

class EditorController extends StateNotifier<EditorState> {
  EditorController(
    this._paletteService, {
    this.autosaveEnabled = true,
    this.autosaveDirectoryPath,
  }) : super(const EditorState());

  final PaletteService _paletteService;
  final bool autosaveEnabled;
  final String? autosaveDirectoryPath;
  static const _filesChannel = MethodChannel('top.mossmoss.pindoustudio/files');
  static const _autosaveName = 'autosave${ProjectCodec.extension}';

  Timer? _autosaveTimer;
  File? _cachedAutosaveFile;
  bool _projectOperationInProgress = false;
  int _autosaveRevision = 0;

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
      if (autosaveEnabled) await _restoreAutosave();
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
    _updateState(
      state.copyWith(
        sourceBytes: bytes,
        sourceName: name,
        sourceWidth: dimensions.$1,
        sourceHeight: dimensions.$2,
        crop: CropSpec.full,
        patternWidth: 40,
        patternHeight: (40 / aspect).round().clamp(8, 200),
        clearPattern: true,
        clearError: true,
      ),
    );
  }

  void applyCrop(CropSpec crop) {
    final updated = state.copyWith(crop: crop);
    _updateState(
      updated.copyWith(
        patternHeight: updated.lockAspectRatio
            ? _heightForWidth(updated.patternWidth, updated)
            : updated.patternHeight,
        clearPattern: true,
        clearError: true,
      ),
    );
  }

  void setPatternWidth(int value) {
    final width = value.clamp(8, 200);
    _updateState(
      state.copyWith(
        patternWidth: width,
        patternHeight: state.lockAspectRatio
            ? _heightForWidth(width, state)
            : state.patternHeight,
        clearPattern: true,
      ),
    );
  }

  void setPatternHeight(int value) {
    final height = value.clamp(8, 200);
    _updateState(
      state.copyWith(
        patternHeight: height,
        patternWidth: state.lockAspectRatio
            ? _widthForHeight(height, state)
            : state.patternWidth,
        clearPattern: true,
      ),
    );
  }

  void setAspectRatioLocked(bool value) {
    _updateState(
      state.copyWith(
        lockAspectRatio: value,
        patternHeight: value
            ? _heightForWidth(state.patternWidth, state)
            : state.patternHeight,
        clearPattern: true,
      ),
    );
  }

  void setBrand(String brand) {
    final palette = state.palettes.where((item) => item.brand == brand).first;
    _updateState(
      state.copyWith(
        selectedBrand: brand,
        maximumColors: state.maximumColors.clamp(1, palette.colors.length),
        clearPattern: true,
      ),
    );
  }

  void setMaximumColors(int value) {
    final maximum = state.selectedPalette?.colors.length ?? 32;
    _updateState(
      state.copyWith(
        maximumColors: value.clamp(1, maximum),
        clearPattern: true,
      ),
    );
  }

  void setDither(bool value) {
    _updateState(state.copyWith(dither: value, clearPattern: true));
  }

  void setShowGrid(bool value) {
    _updateState(state.copyWith(showGrid: value));
  }

  void setShowColorCodes(bool value) {
    _updateState(state.copyWith(showColorCodes: value));
  }

  void setColorEditing(bool value) {
    if (state.pattern == null) return;
    _updateState(state.copyWith(isColorEditing: value, clearSelection: !value));
  }

  void toggleSelectedCell(int index) {
    final pattern = state.pattern;
    if (!state.isColorEditing ||
        pattern == null ||
        index < 0 ||
        index >= pattern.colorIndices.length) {
      return;
    }
    final selected = Set<int>.of(state.selectedCells);
    if (!selected.add(index)) selected.remove(index);
    _updateState(state.copyWith(selectedCells: selected));
  }

  void clearSelectedCells() {
    if (state.selectedCells.isEmpty) return;
    _updateState(state.copyWith(clearSelection: true));
  }

  void selectMatchingColor() {
    final pattern = state.pattern;
    if (pattern == null || state.selectedCells.isEmpty) return;
    final firstCell = state.selectedCells.first;
    final colorIndex = pattern.colorIndices[firstCell];
    final selected = <int>{};
    for (var i = 0; i < pattern.colorIndices.length; i++) {
      if (pattern.colorIndices[i] == colorIndex) selected.add(i);
    }
    _updateState(state.copyWith(selectedCells: selected));
  }

  void replaceSelectedColor(BeadColor color) {
    final pattern = state.pattern;
    if (pattern == null || state.selectedCells.isEmpty) return;
    final updated = pattern.replaceCells(state.selectedCells, color);
    _updateState(
      state.copyWith(pattern: updated, clearSelection: true, clearError: true),
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clearNotice() {
    state = state.copyWith(clearNotice: true);
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
      _updateState(state.copyWith(pattern: pattern, isProcessing: false));
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
      final showColorCodes = state.showColorCodes;
      final bytes = await Isolate.run(
        () => renderPatternJpeg(
          pattern,
          showGrid: showGrid,
          showColorCodes: showColorCodes,
        ),
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

  Future<String?> saveProject() async {
    if (_projectOperationInProgress ||
        (state.sourceBytes == null && state.pattern == null)) {
      return null;
    }
    _projectOperationInProgress = true;
    try {
      final snapshot = state;
      final bytes = await Isolate.run(() => ProjectCodec.encode(snapshot));
      final baseName = p.basenameWithoutExtension(state.sourceName ?? '未命名');
      final safeName = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName = '${safeName}_拼豆工程${ProjectCodec.extension}';
      final String? savedPath;
      if (Platform.isAndroid) {
        savedPath = await _filesChannel.invokeMethod<String>(
          'saveProject',
          <String, Object>{'bytes': bytes, 'fileName': fileName},
        );
      } else if (Platform.isWindows) {
        final location = await _filesChannel.invokeMethod<String>(
          'pickProjectSavePath',
          <String, Object>{'fileName': fileName},
        );
        if (location == null) return null;
        await File(location).writeAsBytes(bytes, flush: true);
        savedPath = location;
      } else {
        throw UnsupportedError('当前平台暂未适配工程保存。');
      }
      if (mounted && savedPath != null) {
        state = state.copyWith(noticeMessage: '工程已保存：$savedPath');
      }
      return savedPath;
    } catch (error) {
      if (mounted) state = state.copyWith(errorMessage: '工程保存失败：$error');
      return null;
    } finally {
      _projectOperationInProgress = false;
    }
  }

  Future<String?> openProject() async {
    if (_projectOperationInProgress || state.isProcessing) return null;
    _projectOperationInProgress = true;
    try {
      final Uint8List bytes;
      final String displayName;
      final String returnPath;
      if (Platform.isAndroid) {
        final selected = await _filesChannel.invokeMapMethod<String, dynamic>(
          'pickProject',
        );
        if (selected == null) return null;
        final selectedBytes = selected['bytes'] as Uint8List?;
        if (selectedBytes == null) {
          throw const FormatException('未能读取所选工程文件。');
        }
        bytes = selectedBytes;
        displayName = selected['name'] as String? ?? '拼豆工程';
        returnPath = displayName;
      } else if (Platform.isWindows) {
        final selectedPath = await _filesChannel.invokeMethod<String>(
          'pickProject',
        );
        if (selectedPath == null) return null;
        bytes = await File(selectedPath).readAsBytes();
        displayName = p.basename(selectedPath);
        returnPath = selectedPath;
      } else {
        throw UnsupportedError('当前平台暂未适配工程恢复。');
      }

      final palettes = state.palettes;
      final restored = await Isolate.run(
        () => ProjectCodec.decode(bytes, palettes: palettes),
      );
      if (!mounted) return returnPath;
      state = restored.copyWith(
        noticeMessage: '已恢复工程：$displayName',
        clearError: true,
      );
      _autosaveRevision++;
      await _writeAutosave(ignoreRevision: true);
      return returnPath;
    } catch (error) {
      if (mounted) state = state.copyWith(errorMessage: '工程恢复失败：$error');
      return null;
    } finally {
      _projectOperationInProgress = false;
    }
  }

  Future<void> flushAutosave() async {
    if (!autosaveEnabled) return;
    _autosaveTimer?.cancel();
    await _writeAutosave(ignoreRevision: true);
  }

  void _updateState(EditorState next) {
    state = next;
    _autosaveRevision++;
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    if (!autosaveEnabled) return;
    if (state.sourceBytes == null && state.pattern == null) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 600), _writeAutosave);
  }

  Future<void> _restoreAutosave() async {
    final file = await _resolveAutosaveFile();
    if (file == null || !await file.exists()) return;
    try {
      final bytes = await file.readAsBytes();
      final palettes = state.palettes;
      final restored = await Isolate.run(
        () => ProjectCodec.decode(bytes, palettes: palettes),
      );
      if (!mounted) return;
      state = restored.copyWith(noticeMessage: '已自动恢复上次编辑', clearError: true);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: '上次编辑自动恢复失败：$error');
    }
  }

  Future<void> _writeAutosave({bool ignoreRevision = false}) async {
    if (!mounted || (state.sourceBytes == null && state.pattern == null)) {
      return;
    }
    final revision = _autosaveRevision;
    final snapshot = state;
    try {
      final bytes = await Isolate.run(() => ProjectCodec.encode(snapshot));
      if (!mounted || (!ignoreRevision && revision != _autosaveRevision)) {
        return;
      }
      final file = await _resolveAutosaveFile();
      if (file == null) return;
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    } on Object catch (error) {
      if (mounted) state = state.copyWith(errorMessage: '自动保存失败：$error');
    }
  }

  Future<File?> _resolveAutosaveFile() async {
    if (_cachedAutosaveFile case final file?) return file;
    try {
      final String? directoryPath;
      if (autosaveDirectoryPath != null) {
        directoryPath = autosaveDirectoryPath;
      } else if (Platform.isWindows) {
        final appData =
            Platform.environment['APPDATA'] ??
            Platform.environment['LOCALAPPDATA'];
        directoryPath = appData == null
            ? null
            : p.join(appData, 'PindouStudio');
      } else if (Platform.isAndroid) {
        final appData = await _filesChannel.invokeMethod<String>(
          'getAppDataPath',
        );
        directoryPath = appData == null
            ? null
            : p.join(appData, 'pindou-studio');
      } else {
        directoryPath = null;
      }
      if (directoryPath == null) return null;
      return _cachedAutosaveFile = File(p.join(directoryPath, _autosaveName));
    } on PlatformException {
      return null;
    } on MissingPluginException {
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

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }
}
