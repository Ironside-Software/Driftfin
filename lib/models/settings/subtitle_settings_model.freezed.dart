// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'subtitle_settings_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SubtitleSettingsModel implements DiagnosticableTreeMixin {
  double get fontSize;
  @FontWeightConverter()
  FontWeight get fontWeight;
  double get verticalOffset;
  @SubtitleColorConverter()
  Color get color;
  @SubtitleColorConverter()
  Color get outlineColor;
  double get outlineSize;
  @SubtitleColorConverter()
  Color get backGroundColor;
  double get shadow;

  /// Create a copy of SubtitleSettingsModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SubtitleSettingsModelCopyWith<SubtitleSettingsModel> get copyWith =>
      _$SubtitleSettingsModelCopyWithImpl<SubtitleSettingsModel>(
          this as SubtitleSettingsModel, _$identity);

  /// Serializes this SubtitleSettingsModel to a JSON map.
  Map<String, dynamic> toJson();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
      ..add(DiagnosticsProperty('type', 'SubtitleSettingsModel'))
      ..add(DiagnosticsProperty('fontSize', fontSize))
      ..add(DiagnosticsProperty('fontWeight', fontWeight))
      ..add(DiagnosticsProperty('verticalOffset', verticalOffset))
      ..add(DiagnosticsProperty('color', color))
      ..add(DiagnosticsProperty('outlineColor', outlineColor))
      ..add(DiagnosticsProperty('outlineSize', outlineSize))
      ..add(DiagnosticsProperty('backGroundColor', backGroundColor))
      ..add(DiagnosticsProperty('shadow', shadow));
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'SubtitleSettingsModel(fontSize: $fontSize, fontWeight: $fontWeight, verticalOffset: $verticalOffset, color: $color, outlineColor: $outlineColor, outlineSize: $outlineSize, backGroundColor: $backGroundColor, shadow: $shadow)';
  }
}

/// @nodoc
abstract mixin class $SubtitleSettingsModelCopyWith<$Res> {
  factory $SubtitleSettingsModelCopyWith(SubtitleSettingsModel value,
          $Res Function(SubtitleSettingsModel) _then) =
      _$SubtitleSettingsModelCopyWithImpl;
  @useResult
  $Res call(
      {double fontSize,
      @FontWeightConverter() FontWeight fontWeight,
      double verticalOffset,
      @SubtitleColorConverter() Color color,
      @SubtitleColorConverter() Color outlineColor,
      double outlineSize,
      @SubtitleColorConverter() Color backGroundColor,
      double shadow});
}

/// @nodoc
class _$SubtitleSettingsModelCopyWithImpl<$Res>
    implements $SubtitleSettingsModelCopyWith<$Res> {
  _$SubtitleSettingsModelCopyWithImpl(this._self, this._then);

  final SubtitleSettingsModel _self;
  final $Res Function(SubtitleSettingsModel) _then;

  /// Create a copy of SubtitleSettingsModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fontSize = null,
    Object? fontWeight = null,
    Object? verticalOffset = null,
    Object? color = null,
    Object? outlineColor = null,
    Object? outlineSize = null,
    Object? backGroundColor = null,
    Object? shadow = null,
  }) {
    return _then(_self.copyWith(
      fontSize: null == fontSize
          ? _self.fontSize
          : fontSize // ignore: cast_nullable_to_non_nullable
              as double,
      fontWeight: null == fontWeight
          ? _self.fontWeight
          : fontWeight // ignore: cast_nullable_to_non_nullable
              as FontWeight,
      verticalOffset: null == verticalOffset
          ? _self.verticalOffset
          : verticalOffset // ignore: cast_nullable_to_non_nullable
              as double,
      color: null == color
          ? _self.color
          : color // ignore: cast_nullable_to_non_nullable
              as Color,
      outlineColor: null == outlineColor
          ? _self.outlineColor
          : outlineColor // ignore: cast_nullable_to_non_nullable
              as Color,
      outlineSize: null == outlineSize
          ? _self.outlineSize
          : outlineSize // ignore: cast_nullable_to_non_nullable
              as double,
      backGroundColor: null == backGroundColor
          ? _self.backGroundColor
          : backGroundColor // ignore: cast_nullable_to_non_nullable
              as Color,
      shadow: null == shadow
          ? _self.shadow
          : shadow // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [SubtitleSettingsModel].
extension SubtitleSettingsModelPatterns on SubtitleSettingsModel {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_SubtitleSettingsModel value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SubtitleSettingsModel() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_SubtitleSettingsModel value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SubtitleSettingsModel():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_SubtitleSettingsModel value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SubtitleSettingsModel() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            double fontSize,
            @FontWeightConverter() FontWeight fontWeight,
            double verticalOffset,
            @SubtitleColorConverter() Color color,
            @SubtitleColorConverter() Color outlineColor,
            double outlineSize,
            @SubtitleColorConverter() Color backGroundColor,
            double shadow)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SubtitleSettingsModel() when $default != null:
        return $default(
            _that.fontSize,
            _that.fontWeight,
            _that.verticalOffset,
            _that.color,
            _that.outlineColor,
            _that.outlineSize,
            _that.backGroundColor,
            _that.shadow);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            double fontSize,
            @FontWeightConverter() FontWeight fontWeight,
            double verticalOffset,
            @SubtitleColorConverter() Color color,
            @SubtitleColorConverter() Color outlineColor,
            double outlineSize,
            @SubtitleColorConverter() Color backGroundColor,
            double shadow)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SubtitleSettingsModel():
        return $default(
            _that.fontSize,
            _that.fontWeight,
            _that.verticalOffset,
            _that.color,
            _that.outlineColor,
            _that.outlineSize,
            _that.backGroundColor,
            _that.shadow);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            double fontSize,
            @FontWeightConverter() FontWeight fontWeight,
            double verticalOffset,
            @SubtitleColorConverter() Color color,
            @SubtitleColorConverter() Color outlineColor,
            double outlineSize,
            @SubtitleColorConverter() Color backGroundColor,
            double shadow)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SubtitleSettingsModel() when $default != null:
        return $default(
            _that.fontSize,
            _that.fontWeight,
            _that.verticalOffset,
            _that.color,
            _that.outlineColor,
            _that.outlineSize,
            _that.backGroundColor,
            _that.shadow);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SubtitleSettingsModel extends SubtitleSettingsModel
    with DiagnosticableTreeMixin {
  const _SubtitleSettingsModel(
      {this.fontSize = 60.0,
      @FontWeightConverter() this.fontWeight = FontWeight.normal,
      this.verticalOffset = 0.10,
      @SubtitleColorConverter() this.color = Colors.white,
      @SubtitleColorConverter()
      this.outlineColor = const Color.fromRGBO(0, 0, 0, 0.85),
      this.outlineSize = 4.0,
      @SubtitleColorConverter()
      this.backGroundColor = const Color.fromARGB(0, 0, 0, 0),
      this.shadow = 0.5})
      : super._();
  factory _SubtitleSettingsModel.fromJson(Map<String, dynamic> json) =>
      _$SubtitleSettingsModelFromJson(json);

  @override
  @JsonKey()
  final double fontSize;
  @override
  @JsonKey()
  @FontWeightConverter()
  final FontWeight fontWeight;
  @override
  @JsonKey()
  final double verticalOffset;
  @override
  @JsonKey()
  @SubtitleColorConverter()
  final Color color;
  @override
  @JsonKey()
  @SubtitleColorConverter()
  final Color outlineColor;
  @override
  @JsonKey()
  final double outlineSize;
  @override
  @JsonKey()
  @SubtitleColorConverter()
  final Color backGroundColor;
  @override
  @JsonKey()
  final double shadow;

  /// Create a copy of SubtitleSettingsModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SubtitleSettingsModelCopyWith<_SubtitleSettingsModel> get copyWith =>
      __$SubtitleSettingsModelCopyWithImpl<_SubtitleSettingsModel>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SubtitleSettingsModelToJson(
      this,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
      ..add(DiagnosticsProperty('type', 'SubtitleSettingsModel'))
      ..add(DiagnosticsProperty('fontSize', fontSize))
      ..add(DiagnosticsProperty('fontWeight', fontWeight))
      ..add(DiagnosticsProperty('verticalOffset', verticalOffset))
      ..add(DiagnosticsProperty('color', color))
      ..add(DiagnosticsProperty('outlineColor', outlineColor))
      ..add(DiagnosticsProperty('outlineSize', outlineSize))
      ..add(DiagnosticsProperty('backGroundColor', backGroundColor))
      ..add(DiagnosticsProperty('shadow', shadow));
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'SubtitleSettingsModel(fontSize: $fontSize, fontWeight: $fontWeight, verticalOffset: $verticalOffset, color: $color, outlineColor: $outlineColor, outlineSize: $outlineSize, backGroundColor: $backGroundColor, shadow: $shadow)';
  }
}

/// @nodoc
abstract mixin class _$SubtitleSettingsModelCopyWith<$Res>
    implements $SubtitleSettingsModelCopyWith<$Res> {
  factory _$SubtitleSettingsModelCopyWith(_SubtitleSettingsModel value,
          $Res Function(_SubtitleSettingsModel) _then) =
      __$SubtitleSettingsModelCopyWithImpl;
  @override
  @useResult
  $Res call(
      {double fontSize,
      @FontWeightConverter() FontWeight fontWeight,
      double verticalOffset,
      @SubtitleColorConverter() Color color,
      @SubtitleColorConverter() Color outlineColor,
      double outlineSize,
      @SubtitleColorConverter() Color backGroundColor,
      double shadow});
}

/// @nodoc
class __$SubtitleSettingsModelCopyWithImpl<$Res>
    implements _$SubtitleSettingsModelCopyWith<$Res> {
  __$SubtitleSettingsModelCopyWithImpl(this._self, this._then);

  final _SubtitleSettingsModel _self;
  final $Res Function(_SubtitleSettingsModel) _then;

  /// Create a copy of SubtitleSettingsModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? fontSize = null,
    Object? fontWeight = null,
    Object? verticalOffset = null,
    Object? color = null,
    Object? outlineColor = null,
    Object? outlineSize = null,
    Object? backGroundColor = null,
    Object? shadow = null,
  }) {
    return _then(_SubtitleSettingsModel(
      fontSize: null == fontSize
          ? _self.fontSize
          : fontSize // ignore: cast_nullable_to_non_nullable
              as double,
      fontWeight: null == fontWeight
          ? _self.fontWeight
          : fontWeight // ignore: cast_nullable_to_non_nullable
              as FontWeight,
      verticalOffset: null == verticalOffset
          ? _self.verticalOffset
          : verticalOffset // ignore: cast_nullable_to_non_nullable
              as double,
      color: null == color
          ? _self.color
          : color // ignore: cast_nullable_to_non_nullable
              as Color,
      outlineColor: null == outlineColor
          ? _self.outlineColor
          : outlineColor // ignore: cast_nullable_to_non_nullable
              as Color,
      outlineSize: null == outlineSize
          ? _self.outlineSize
          : outlineSize // ignore: cast_nullable_to_non_nullable
              as double,
      backGroundColor: null == backGroundColor
          ? _self.backGroundColor
          : backGroundColor // ignore: cast_nullable_to_non_nullable
              as Color,
      shadow: null == shadow
          ? _self.shadow
          : shadow // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

// dart format on
