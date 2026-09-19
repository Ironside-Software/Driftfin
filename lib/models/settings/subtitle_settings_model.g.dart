// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtitle_settings_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SubtitleSettingsModel _$SubtitleSettingsModelFromJson(
        Map<String, dynamic> json) =>
    _SubtitleSettingsModel(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 60.0,
      fontWeight: json['fontWeight'] == null
          ? FontWeight.normal
          : const FontWeightConverter()
              .fromJson((json['fontWeight'] as num).toInt()),
      verticalOffset: (json['verticalOffset'] as num?)?.toDouble() ?? 0.10,
      color: json['color'] == null
          ? Colors.white
          : const SubtitleColorConverter().fromJson(json['color']),
      outlineColor: json['outlineColor'] == null
          ? const Color.fromRGBO(0, 0, 0, 0.85)
          : const SubtitleColorConverter().fromJson(json['outlineColor']),
      outlineSize: (json['outlineSize'] as num?)?.toDouble() ?? 4.0,
      backGroundColor: json['backGroundColor'] == null
          ? const Color.fromARGB(0, 0, 0, 0)
          : const SubtitleColorConverter().fromJson(json['backGroundColor']),
      shadow: (json['shadow'] as num?)?.toDouble() ?? 0.5,
    );

Map<String, dynamic> _$SubtitleSettingsModelToJson(
        _SubtitleSettingsModel instance) =>
    <String, dynamic>{
      'fontSize': instance.fontSize,
      'fontWeight': const FontWeightConverter().toJson(instance.fontWeight),
      'verticalOffset': instance.verticalOffset,
      'color': const SubtitleColorConverter().toJson(instance.color),
      'outlineColor':
          const SubtitleColorConverter().toJson(instance.outlineColor),
      'outlineSize': instance.outlineSize,
      'backGroundColor':
          const SubtitleColorConverter().toJson(instance.backGroundColor),
      'shadow': instance.shadow,
    };
