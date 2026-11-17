import 'package:flutter/material.dart';

enum FaceStyle {
  happy('Happy'),
  wink('Wink'),
  starry('Starry'),
  cool('Cool'),
  shy('Shy'),
  sleepy('Sleepy');

  final String label;
  const FaceStyle(this.label);
}

enum AccessoryStyle {
  none('None'),
  crown('Crown'),
  bow('Bow'),
  halo('Halo'),
  cap('Cap'),
  headband('Headband');

  final String label;
  const AccessoryStyle(this.label);
}

enum ShoeStyle {
  classic('Classic'),
  sneakers('Sneakers'),
  boots('Boots'),
  roller('Roller'),
  cloud('Cloud'),
  star('Star');

  final String label;
  const ShoeStyle(this.label);
}

class ToyCustomization {
  final Color? bodyColorOverride;
  final Color? accentColorOverride;
  final FaceStyle faceStyle;
  final AccessoryStyle accessoryStyle;
  final ShoeStyle shoeStyle;
  final String? nickname;

  const ToyCustomization({
    this.bodyColorOverride,
    this.accentColorOverride,
    this.faceStyle = FaceStyle.happy,
    this.accessoryStyle = AccessoryStyle.none,
    this.shoeStyle = ShoeStyle.classic,
    this.nickname,
  });

  ToyCustomization copyWith({
    Color? bodyColorOverride,
    bool clearBodyColor = false,
    Color? accentColorOverride,
    bool clearAccentColor = false,
    FaceStyle? faceStyle,
    AccessoryStyle? accessoryStyle,
    ShoeStyle? shoeStyle,
    String? nickname,
    bool clearNickname = false,
  }) {
    return ToyCustomization(
      bodyColorOverride:
          clearBodyColor ? null : (bodyColorOverride ?? this.bodyColorOverride),
      accentColorOverride: clearAccentColor
          ? null
          : (accentColorOverride ?? this.accentColorOverride),
      faceStyle: faceStyle ?? this.faceStyle,
      accessoryStyle: accessoryStyle ?? this.accessoryStyle,
      shoeStyle: shoeStyle ?? this.shoeStyle,
      nickname: clearNickname ? null : (nickname ?? this.nickname),
    );
  }

  Map<String, dynamic> toJson() => {
        if (bodyColorOverride != null)
          'bodyColorOverride': bodyColorOverride!.toARGB32(),
        if (accentColorOverride != null)
          'accentColorOverride': accentColorOverride!.toARGB32(),
        'faceStyle': faceStyle.name,
        'accessoryStyle': accessoryStyle.name,
        'shoeStyle': shoeStyle.name,
        if (nickname != null && nickname!.isNotEmpty) 'nickname': nickname,
      };

  factory ToyCustomization.fromJson(Map<String, dynamic> json) {
    return ToyCustomization(
      bodyColorOverride: json['bodyColorOverride'] is int
          ? Color(json['bodyColorOverride'] as int)
          : null,
      accentColorOverride: json['accentColorOverride'] is int
          ? Color(json['accentColorOverride'] as int)
          : null,
      faceStyle: FaceStyle.values.firstWhere(
        (e) => e.name == json['faceStyle'],
        orElse: () => FaceStyle.happy,
      ),
      accessoryStyle: AccessoryStyle.values.firstWhere(
        (e) => e.name == json['accessoryStyle'],
        orElse: () => AccessoryStyle.none,
      ),
      shoeStyle: ShoeStyle.values.firstWhere(
        (e) => e.name == json['shoeStyle'],
        orElse: () => ShoeStyle.classic,
      ),
      nickname: json['nickname'] as String?,
    );
  }
}

class HatchedToy {
  final String instanceId;
  final String toyId;
  final DateTime hatchedAt;
  final ToyCustomization customization;

  const HatchedToy({
    required this.instanceId,
    required this.toyId,
    required this.hatchedAt,
    this.customization = const ToyCustomization(),
  });

  HatchedToy copyWith({
    ToyCustomization? customization,
  }) {
    return HatchedToy(
      instanceId: instanceId,
      toyId: toyId,
      hatchedAt: hatchedAt,
      customization: customization ?? this.customization,
    );
  }

  Map<String, dynamic> toJson() => {
        'instanceId': instanceId,
        'toyId': toyId,
        'hatchedAt': hatchedAt.toIso8601String(),
        'customization': customization.toJson(),
      };

  factory HatchedToy.fromJson(Map<String, dynamic> json) {
    return HatchedToy(
      instanceId: json['instanceId'] as String,
      toyId: json['toyId'] as String,
      hatchedAt: DateTime.tryParse(json['hatchedAt'] as String? ?? '') ??
          DateTime.now(),
      customization: json['customization'] is Map<String, dynamic>
          ? ToyCustomization.fromJson(
              json['customization'] as Map<String, dynamic>,
            )
          : const ToyCustomization(),
    );
  }
}
