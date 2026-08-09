import 'dart:convert';
import 'dart:typed_data';

import '../features/editor/editor_state.dart';
import '../models/bead_color.dart';
import '../models/crop_spec.dart';
import '../models/pattern.dart';

class ProjectCodec {
  const ProjectCodec._();

  static const format = 'pindou-studio-project';
  static const version = 1;
  static const extension = '.pindou';

  static Uint8List encode(EditorState state) {
    final sourceBytes = state.sourceBytes;
    final pattern = state.pattern;
    final selectedCells = state.selectedCells.toList()..sort();
    final document = <String, Object?>{
      'format': format,
      'version': version,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'source': sourceBytes == null
          ? null
          : <String, Object?>{
              'name': state.sourceName,
              'width': state.sourceWidth,
              'height': state.sourceHeight,
              'bytes': base64Encode(sourceBytes),
            },
      'editor': <String, Object?>{
        'selectedBrand': state.selectedBrand,
        'crop': state.crop.toJson(),
        'patternWidth': state.patternWidth,
        'patternHeight': state.patternHeight,
        'lockAspectRatio': state.lockAspectRatio,
        'maximumColors': state.maximumColors,
        'dither': state.dither,
        'showGrid': state.showGrid,
        'showColorCodes': state.showColorCodes,
        'isColorEditing': state.isColorEditing,
        'selectedCells': selectedCells,
      },
      'pattern': pattern == null
          ? null
          : <String, Object>{
              'width': pattern.width,
              'height': pattern.height,
              'colorIndices': pattern.colorIndices,
              'colors': [for (final color in pattern.colors) color.toJson()],
            },
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(document)));
  }

  static EditorState decode(
    Uint8List bytes, {
    required List<BeadPalette> palettes,
  }) {
    if (palettes.isEmpty) {
      throw const FormatException('色库尚未加载，无法恢复工程。');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object catch (error) {
      throw FormatException('工程文件不是有效的 JSON：$error');
    }
    final root = _asMap(decoded, '工程文件');
    if (root['format'] != format) {
      throw const FormatException('文件不是拼豆工坊工程。');
    }
    final fileVersion = _asInt(root['version'], 'version');
    if (fileVersion != version) {
      throw FormatException('暂不支持工程文件版本 $fileVersion。');
    }

    final editor = _asMap(root['editor'], 'editor');
    final requestedBrand = editor['selectedBrand'] as String?;
    final selectedPalette = palettes.firstWhere(
      (palette) => palette.brand == requestedBrand,
      orElse: () => palettes.first,
    );
    final crop = CropSpec.fromJson(_asMap(editor['crop'], 'crop'));
    _validateCrop(crop);

    Uint8List? sourceBytes;
    String? sourceName;
    int? sourceWidth;
    int? sourceHeight;
    if (root['source'] != null) {
      final source = _asMap(root['source'], 'source');
      sourceName = source['name'] as String?;
      sourceWidth = _positiveInt(source['width'], 'source.width');
      sourceHeight = _positiveInt(source['height'], 'source.height');
      final encodedBytes = source['bytes'];
      if (encodedBytes is! String || encodedBytes.isEmpty) {
        throw const FormatException('工程文件中的原图数据无效。');
      }
      try {
        sourceBytes = base64Decode(encodedBytes);
      } on Object catch (error) {
        throw FormatException('工程文件中的原图数据损坏：$error');
      }
    }

    Pattern? pattern;
    if (root['pattern'] != null) {
      pattern = _decodePattern(_asMap(root['pattern'], 'pattern'));
    }

    final selectedCells = <int>{};
    final rawSelected = editor['selectedCells'];
    if (rawSelected is List && pattern != null) {
      for (final value in rawSelected) {
        if (value is num) {
          final index = value.toInt();
          if (index >= 0 && index < pattern.colorIndices.length) {
            selectedCells.add(index);
          }
        }
      }
    }

    final maximumColors = _asInt(
      editor['maximumColors'],
      'maximumColors',
    ).clamp(1, selectedPalette.colors.length);
    return EditorState(
      palettes: palettes,
      selectedBrand: selectedPalette.brand,
      sourceBytes: sourceBytes,
      sourceName: sourceName,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      crop: crop,
      patternWidth: _boundedDimension(editor['patternWidth'], 'patternWidth'),
      patternHeight: _boundedDimension(
        editor['patternHeight'],
        'patternHeight',
      ),
      lockAspectRatio: _asBool(editor['lockAspectRatio'], true),
      maximumColors: maximumColors,
      dither: _asBool(editor['dither'], false),
      showGrid: _asBool(editor['showGrid'], true),
      showColorCodes: _asBool(editor['showColorCodes'], true),
      isColorEditing:
          pattern != null && _asBool(editor['isColorEditing'], false),
      selectedCells: Set<int>.unmodifiable(selectedCells),
      pattern: pattern,
      isLoadingPalettes: false,
    );
  }

  static Pattern _decodePattern(Map<String, dynamic> json) {
    final width = _positiveInt(json['width'], 'pattern.width');
    final height = _positiveInt(json['height'], 'pattern.height');
    if (width > 200 || height > 200) {
      throw const FormatException('工程图案尺寸超出 200 × 200 的上限。');
    }
    final rawColors = json['colors'];
    if (rawColors is! List || rawColors.isEmpty) {
      throw const FormatException('工程文件没有有效的图案颜色。');
    }
    final colors = <BeadColor>[
      for (final value in rawColors)
        BeadColor.fromJson(_asMap(value, 'pattern.colors')),
    ];
    final rawIndices = json['colorIndices'];
    if (rawIndices is! List || rawIndices.length != width * height) {
      throw const FormatException('工程文件中的图案色块数量不正确。');
    }
    final indices = <int>[];
    final counts = List<int>.filled(colors.length, 0);
    for (final value in rawIndices) {
      final index = _asInt(value, 'pattern.colorIndices');
      if (index < 0 || index >= colors.length) {
        throw const FormatException('工程文件包含越界的颜色索引。');
      }
      indices.add(index);
      counts[index]++;
    }
    return Pattern(
      width: width,
      height: height,
      colorIndices: List<int>.unmodifiable(indices),
      colors: List<BeadColor>.unmodifiable(colors),
      counts: List<int>.unmodifiable(counts),
    );
  }

  static Map<String, dynamic> _asMap(Object? value, String field) {
    if (value is! Map) {
      throw FormatException('$field 字段格式无效。');
    }
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static int _asInt(Object? value, String field) {
    if (value is! num || !value.isFinite) {
      throw FormatException('$field 字段不是有效整数。');
    }
    return value.toInt();
  }

  static int _positiveInt(Object? value, String field) {
    final result = _asInt(value, field);
    if (result <= 0) throw FormatException('$field 字段必须大于 0。');
    return result;
  }

  static int _boundedDimension(Object? value, String field) {
    final result = _asInt(value, field);
    if (result < 8 || result > 200) {
      throw FormatException('$field 字段必须在 8 到 200 之间。');
    }
    return result;
  }

  static bool _asBool(Object? value, bool fallback) {
    return value is bool ? value : fallback;
  }

  static void _validateCrop(CropSpec crop) {
    final values = <double>[crop.left, crop.top, crop.width, crop.height];
    if (values.any((value) => !value.isFinite) ||
        crop.left < 0 ||
        crop.top < 0 ||
        crop.width <= 0 ||
        crop.height <= 0 ||
        crop.left + crop.width > 1.000001 ||
        crop.top + crop.height > 1.000001) {
      throw const FormatException('工程文件中的裁剪区域无效。');
    }
  }
}
