import 'package:flutter/material.dart';

@immutable
class BeadColor {
  const BeadColor({
    required this.code,
    required this.name,
    required this.red,
    required this.green,
    required this.blue,
  });

  factory BeadColor.fromJson(Map<String, dynamic> json) {
    final rgb = (json['rgb'] as List<dynamic>).cast<num>();
    return BeadColor(
      code: json['code'] as String,
      name: json['name'] as String,
      red: rgb[0].toInt(),
      green: rgb[1].toInt(),
      blue: rgb[2].toInt(),
    );
  }

  Map<String, Object> toJson() => <String, Object>{
    'code': code,
    'name': name,
    'rgb': <int>[red, green, blue],
  };

  final String code;
  final String name;
  final int red;
  final int green;
  final int blue;

  Color get color => Color.fromARGB(255, red, green, blue);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BeadColor &&
            other.code == code &&
            other.name == name &&
            other.red == red &&
            other.green == green &&
            other.blue == blue;
  }

  @override
  int get hashCode => Object.hash(code, name, red, green, blue);
}

@immutable
class BeadPalette {
  const BeadPalette({required this.brand, required this.colors});

  factory BeadPalette.fromJson(Map<String, dynamic> json) {
    return BeadPalette(
      brand: json['brand'] as String,
      colors: (json['colors'] as List<dynamic>)
          .map((item) => BeadColor.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String brand;
  final List<BeadColor> colors;
}
