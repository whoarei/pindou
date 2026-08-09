import 'package:flutter/foundation.dart';

@immutable
class CropSpec {
  const CropSpec({
    this.left = 0,
    this.top = 0,
    this.width = 1,
    this.height = 1,
    this.quarterTurns = 0,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final int quarterTurns;

  static const full = CropSpec();

  CropSpec copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
    int? quarterTurns,
  }) {
    return CropSpec(
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      quarterTurns: quarterTurns ?? this.quarterTurns,
    );
  }
}
