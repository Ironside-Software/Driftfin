// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AccountModel implements DiagnosticableTreeMixin {

 String get name; String get id; String get avatar; DateTime get lastUsed; Authentication get authMethod; bool get askForAuthOnLaunch; String get localPin;@CredentialsConverter() CredentialsModel get credentials; SeerrCredentialsModel? get seerrCredentials; bool get managedIntegrations; List<String> get latestItemsExcludes; List<String> get searchQueryHistory; bool get quickConnectState; List<LibraryFiltersModel> get libraryFilters; bool get updateNotificationsEnabled; bool get seerrRequestsEnabled; bool get includeHiddenViews; bool? get incognitoMode;@JsonKey(includeFromJson: false, includeToJson: false) UserPolicy? get policy;@JsonKey(includeFromJson: false, includeToJson: false) ServerConfiguration? get serverConfiguration;@JsonKey(includeFromJson: false, includeToJson: false) UserConfiguration? get userConfiguration;@JsonKey(includeFromJson: false, includeToJson: false) bool? get hasPassword;@JsonKey(includeFromJson: false, includeToJson: false) bool? get hasConfiguredPassword; UserSettings? get userSettings;
/// Create a copy of AccountModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountModelCopyWith<AccountModel> get copyWith => _$AccountModelCopyWithImpl<AccountModel>(this as AccountModel, _$identity);

  /// Serializes this AccountModel to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as AccountModel;
  properties
    ..add(DiagnosticsProperty('type', 'AccountModel'))
    ..add(DiagnosticsProperty('name', _this.name))..add(DiagnosticsProperty('id', _this.id))..add(DiagnosticsProperty('avatar', _this.avatar))..add(DiagnosticsProperty('lastUsed', _this.lastUsed))..add(DiagnosticsProperty('authMethod', _this.authMethod))..add(DiagnosticsProperty('askForAuthOnLaunch', _this.askForAuthOnLaunch))..add(DiagnosticsProperty('localPin', _this.localPin))..add(DiagnosticsProperty('credentials', _this.credentials))..add(DiagnosticsProperty('seerrCredentials', _this.seerrCredentials))..add(DiagnosticsProperty('managedIntegrations', _this.managedIntegrations))..add(DiagnosticsProperty('latestItemsExcludes', _this.latestItemsExcludes))..add(DiagnosticsProperty('searchQueryHistory', _this.searchQueryHistory))..add(DiagnosticsProperty('quickConnectState', _this.quickConnectState))..add(DiagnosticsProperty('libraryFilters', _this.libraryFilters))..add(DiagnosticsProperty('updateNotificationsEnabled', _this.updateNotificationsEnabled))..add(DiagnosticsProperty('seerrRequestsEnabled', _this.seerrRequestsEnabled))..add(DiagnosticsProperty('includeHiddenViews', _this.includeHiddenViews))..add(DiagnosticsProperty('incognitoMode', _this.incognitoMode))..add(DiagnosticsProperty('policy', _this.policy))..add(DiagnosticsProperty('serverConfiguration', _this.serverConfiguration))..add(DiagnosticsProperty('userConfiguration', _this.userConfiguration))..add(DiagnosticsProperty('hasPassword', _this.hasPassword))..add(DiagnosticsProperty('hasConfiguredPassword', _this.hasConfiguredPassword))..add(DiagnosticsProperty('userSettings', _this.userSettings));
}



@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as AccountModel;
  return 'AccountModel(name: ${_this.name}, id: ${_this.id}, avatar: ${_this.avatar}, lastUsed: ${_this.lastUsed}, authMethod: ${_this.authMethod}, askForAuthOnLaunch: ${_this.askForAuthOnLaunch}, localPin: ${_this.localPin}, credentials: ${_this.credentials}, seerrCredentials: ${_this.seerrCredentials}, managedIntegrations: ${_this.managedIntegrations}, latestItemsExcludes: ${_this.latestItemsExcludes}, searchQueryHistory: ${_this.searchQueryHistory}, quickConnectState: ${_this.quickConnectState}, libraryFilters: ${_this.libraryFilters}, updateNotificationsEnabled: ${_this.updateNotificationsEnabled}, seerrRequestsEnabled: ${_this.seerrRequestsEnabled}, includeHiddenViews: ${_this.includeHiddenViews}, incognitoMode: ${_this.incognitoMode}, policy: ${_this.policy}, serverConfiguration: ${_this.serverConfiguration}, userConfiguration: ${_this.userConfiguration}, hasPassword: ${_this.hasPassword}, hasConfiguredPassword: ${_this.hasConfiguredPassword}, userSettings: ${_this.userSettings})';
}


}

/// @nodoc
abstract mixin class $AccountModelCopyWith<$Res>  {
  factory $AccountModelCopyWith(AccountModel value, $Res Function(AccountModel) _then) = _$AccountModelCopyWithImpl;
@useResult
$Res call({
 String name, String id, String avatar, DateTime lastUsed, Authentication authMethod, bool askForAuthOnLaunch, String localPin,@CredentialsConverter() CredentialsModel credentials, SeerrCredentialsModel? seerrCredentials, bool managedIntegrations, List<String> latestItemsExcludes, List<String> searchQueryHistory, bool quickConnectState, List<LibraryFiltersModel> libraryFilters, bool updateNotificationsEnabled, bool seerrRequestsEnabled, bool includeHiddenViews, bool? incognitoMode,@JsonKey(includeFromJson: false, includeToJson: false) UserPolicy? policy,@JsonKey(includeFromJson: false, includeToJson: false) ServerConfiguration? serverConfiguration,@JsonKey(includeFromJson: false, includeToJson: false) UserConfiguration? userConfiguration,@JsonKey(includeFromJson: false, includeToJson: false) bool? hasPassword,@JsonKey(includeFromJson: false, includeToJson: false) bool? hasConfiguredPassword, UserSettings? userSettings
});


$CredentialsModelCopyWith<$Res> get credentials;$SeerrCredentialsModelCopyWith<$Res>? get seerrCredentials;$UserSettingsCopyWith<$Res>? get userSettings;

}
/// @nodoc
class _$AccountModelCopyWithImpl<$Res>
    implements $AccountModelCopyWith<$Res> {
  _$AccountModelCopyWithImpl(this._self, this._then);

  final AccountModel _self;
  final $Res Function(AccountModel) _then;

/// Create a copy of AccountModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? id = null,Object? avatar = null,Object? lastUsed = null,Object? authMethod = null,Object? askForAuthOnLaunch = null,Object? localPin = null,Object? credentials = null,Object? seerrCredentials = freezed,Object? managedIntegrations = null,Object? latestItemsExcludes = null,Object? searchQueryHistory = null,Object? quickConnectState = null,Object? libraryFilters = null,Object? updateNotificationsEnabled = null,Object? seerrRequestsEnabled = null,Object? includeHiddenViews = null,Object? incognitoMode = freezed,Object? policy = freezed,Object? serverConfiguration = freezed,Object? userConfiguration = freezed,Object? hasPassword = freezed,Object? hasConfiguredPassword = freezed,Object? userSettings = freezed,}) {
  return _then(AccountModel(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,avatar: null == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String,lastUsed: null == lastUsed ? _self.lastUsed : lastUsed // ignore: cast_nullable_to_non_nullable
as DateTime,authMethod: null == authMethod ? _self.authMethod : authMethod // ignore: cast_nullable_to_non_nullable
as Authentication,askForAuthOnLaunch: null == askForAuthOnLaunch ? _self.askForAuthOnLaunch : askForAuthOnLaunch // ignore: cast_nullable_to_non_nullable
as bool,localPin: null == localPin ? _self.localPin : localPin // ignore: cast_nullable_to_non_nullable
as String,credentials: null == credentials ? _self.credentials : credentials // ignore: cast_nullable_to_non_nullable
as CredentialsModel,seerrCredentials: freezed == seerrCredentials ? _self.seerrCredentials : seerrCredentials // ignore: cast_nullable_to_non_nullable
as SeerrCredentialsModel?,managedIntegrations: null == managedIntegrations ? _self.managedIntegrations : managedIntegrations // ignore: cast_nullable_to_non_nullable
as bool,latestItemsExcludes: null == latestItemsExcludes ? _self.latestItemsExcludes : latestItemsExcludes // ignore: cast_nullable_to_non_nullable
as List<String>,searchQueryHistory: null == searchQueryHistory ? _self.searchQueryHistory : searchQueryHistory // ignore: cast_nullable_to_non_nullable
as List<String>,quickConnectState: null == quickConnectState ? _self.quickConnectState : quickConnectState // ignore: cast_nullable_to_non_nullable
as bool,libraryFilters: null == libraryFilters ? _self.libraryFilters : libraryFilters // ignore: cast_nullable_to_non_nullable
as List<LibraryFiltersModel>,updateNotificationsEnabled: null == updateNotificationsEnabled ? _self.updateNotificationsEnabled : updateNotificationsEnabled // ignore: cast_nullable_to_non_nullable
as bool,seerrRequestsEnabled: null == seerrRequestsEnabled ? _self.seerrRequestsEnabled : seerrRequestsEnabled // ignore: cast_nullable_to_non_nullable
as bool,includeHiddenViews: null == includeHiddenViews ? _self.includeHiddenViews : includeHiddenViews // ignore: cast_nullable_to_non_nullable
as bool,incognitoMode: freezed == incognitoMode ? _self.incognitoMode : incognitoMode // ignore: cast_nullable_to_non_nullable
as bool?,policy: freezed == policy ? _self.policy : policy // ignore: cast_nullable_to_non_nullable
as UserPolicy?,serverConfiguration: freezed == serverConfiguration ? _self.serverConfiguration : serverConfiguration // ignore: cast_nullable_to_non_nullable
as ServerConfiguration?,userConfiguration: freezed == userConfiguration ? _self.userConfiguration : userConfiguration // ignore: cast_nullable_to_non_nullable
as UserConfiguration?,hasPassword: freezed == hasPassword ? _self.hasPassword : hasPassword // ignore: cast_nullable_to_non_nullable
as bool?,hasConfiguredPassword: freezed == hasConfiguredPassword ? _self.hasConfiguredPassword : hasConfiguredPassword // ignore: cast_nullable_to_non_nullable
as bool?,userSettings: freezed == userSettings ? _self.userSettings : userSettings // ignore: cast_nullable_to_non_nullable
as UserSettings?,
  ));
}
/// Create a copy of AccountModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CredentialsModelCopyWith<$Res> get credentials {
  
  return $CredentialsModelCopyWith<$Res>(_self.credentials, (value) {
    return _then(_self.copyWith(credentials: value));
  });
}/// Create a copy of AccountModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SeerrCredentialsModelCopyWith<$Res>? get seerrCredentials {
    if (_self.seerrCredentials == null) {
    return null;
  }

  return $SeerrCredentialsModelCopyWith<$Res>(_self.seerrCredentials!, (value) {
    return _then(_self.copyWith(seerrCredentials: value));
  });
}/// Create a copy of AccountModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSettingsCopyWith<$Res>? get userSettings {
    if (_self.userSettings == null) {
    return null;
  }

  return $UserSettingsCopyWith<$Res>(_self.userSettings!, (value) {
    return _then(_self.copyWith(userSettings: value));
  });
}
}


/// Adds pattern-matching-related methods to [AccountModel].
extension AccountModelPatterns on AccountModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountModel() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountModel value)  $default,){
final _that = this;
switch (_that) {
case _AccountModel():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountModel value)?  $default,){
final _that = this;
switch (_that) {
case _AccountModel() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String id,  String avatar,  DateTime lastUsed,  Authentication authMethod,  bool askForAuthOnLaunch,  String localPin, @CredentialsConverter()  CredentialsModel credentials,  SeerrCredentialsModel? seerrCredentials,  bool managedIntegrations,  List<String> latestItemsExcludes,  List<String> searchQueryHistory,  bool quickConnectState,  List<LibraryFiltersModel> libraryFilters,  bool updateNotificationsEnabled,  bool seerrRequestsEnabled,  bool includeHiddenViews,  bool? incognitoMode, @JsonKey(includeFromJson: false, includeToJson: false)  UserPolicy? policy, @JsonKey(includeFromJson: false, includeToJson: false)  ServerConfiguration? serverConfiguration, @JsonKey(includeFromJson: false, includeToJson: false)  UserConfiguration? userConfiguration, @JsonKey(includeFromJson: false, includeToJson: false)  bool? hasPassword, @JsonKey(includeFromJson: false, includeToJson: false)  bool? hasConfiguredPassword,  UserSettings? userSettings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountModel() when $default != null:
return $default(_that.name,_that.id,_that.avatar,_that.lastUsed,_that.authMethod,_that.askForAuthOnLaunch,_that.localPin,_that.credentials,_that.seerrCredentials,_that.managedIntegrations,_that.latestItemsExcludes,_that.searchQueryHistory,_that.quickConnectState,_that.libraryFilters,_that.updateNotificationsEnabled,_that.seerrRequestsEnabled,_that.includeHiddenViews,_that.incognitoMode,_that.policy,_that.serverConfiguration,_that.userConfiguration,_that.hasPassword,_that.hasConfiguredPassword,_that.userSettings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String id,  String avatar,  DateTime lastUsed,  Authentication authMethod,  bool askForAuthOnLaunch,  String localPin, @CredentialsConverter()  CredentialsModel credentials,  SeerrCredentialsModel? seerrCredentials,  bool managedIntegrations,  List<String> latestItemsExcludes,  List<String> searchQueryHistory,  bool quickConnectState,  List<LibraryFiltersModel> libraryFilters,  bool updateNotificationsEnabled,  bool seerrRequestsEnabled,  bool includeHiddenViews,  bool? incognitoMode, @JsonKey(includeFromJson: false, includeToJson: false)  UserPolicy? policy, @JsonKey(includeFromJson: false, includeToJson: false)  ServerConfiguration? serverConfiguration, @JsonKey(includeFromJson: false, includeToJson: false)  UserConfiguration? userConfiguration, @JsonKey(includeFromJson: false, includeToJson: false)  bool? hasPassword, @JsonKey(includeFromJson: false, includeToJson: false)  bool? hasConfiguredPassword,  UserSettings? userSettings)  $default,) {final _that = this;
switch (_that) {
case _AccountModel():
return $default(_that.name,_that.id,_that.avatar,_that.lastUsed,_that.authMethod,_that.askForAuthOnLaunch,_that.localPin,_that.credentials,_that.seerrCredentials,_that.managedIntegrations,_that.latestItemsExcludes,_that.searchQueryHistory,_that.quickConnectState,_that.libraryFilters,_that.updateNotificationsEnabled,_that.seerrRequestsEnabled,_that.includeHiddenViews,_that.incognitoMode,_that.policy,_that.serverConfiguration,_that.userConfiguration,_that.hasPassword,_that.hasConfiguredPassword,_that.userSettings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String id,  String avatar,  DateTime lastUsed,  Authentication authMethod,  bool askForAuthOnLaunch,  String localPin, @CredentialsConverter()  CredentialsModel credentials,  SeerrCredentialsModel? seerrCredentials,  bool managedIntegrations,  List<String> latestItemsExcludes,  List<String> searchQueryHistory,  bool quickConnectState,  List<LibraryFiltersModel> libraryFilters,  bool updateNotificationsEnabled,  bool seerrRequestsEnabled,  bool includeHiddenViews,  bool? incognitoMode, @JsonKey(includeFromJson: false, includeToJson: false)  UserPolicy? policy, @JsonKey(includeFromJson: false, includeToJson: false)  ServerConfiguration? serverConfiguration, @JsonKey(includeFromJson: false, includeToJson: false)  UserConfiguration? userConfiguration, @JsonKey(includeFromJson: false, includeToJson: false)  bool? hasPassword, @JsonKey(includeFromJson: false, includeToJson: false)  bool? hasConfiguredPassword,  UserSettings? userSettings)?  $default,) {final _that = this;
switch (_that) {
case _AccountModel() when $default != null:
return $default(_that.name,_that.id,_that.avatar,_that.lastUsed,_that.authMethod,_that.askForAuthOnLaunch,_that.localPin,_that.credentials,_that.seerrCredentials,_that.managedIntegrations,_that.latestItemsExcludes,_that.searchQueryHistory,_that.quickConnectState,_that.libraryFilters,_that.updateNotificationsEnabled,_that.seerrRequestsEnabled,_that.includeHiddenViews,_that.incognitoMode,_that.policy,_that.serverConfiguration,_that.userConfiguration,_that.hasPassword,_that.hasConfiguredPassword,_that.userSettings);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountModel extends AccountModel with DiagnosticableTreeMixin {
  const _AccountModel({required this.name, required this.id, required this.avatar, required this.lastUsed, this.authMethod = Authentication.autoLogin, this.askForAuthOnLaunch = false, this.localPin = "", @CredentialsConverter() required this.credentials, this.seerrCredentials, this.managedIntegrations = false,  List<String> latestItemsExcludes = const [],  List<String> searchQueryHistory = const [], this.quickConnectState = false,  List<LibraryFiltersModel> libraryFilters = const [], this.updateNotificationsEnabled = false, this.seerrRequestsEnabled = false, this.includeHiddenViews = false, this.incognitoMode, @JsonKey(includeFromJson: false, includeToJson: false) this.policy, @JsonKey(includeFromJson: false, includeToJson: false) this.serverConfiguration, @JsonKey(includeFromJson: false, includeToJson: false) this.userConfiguration, @JsonKey(includeFromJson: false, includeToJson: false) this.hasPassword, @JsonKey(includeFromJson: false, includeToJson: false) this.hasConfiguredPassword, this.userSettings}): _latestItemsExcludes = latestItemsExcludes,_searchQueryHistory = searchQueryHistory,_libraryFilters = libraryFilters,super._();
  factory _AccountModel.fromJson(Map<String, dynamic> json) => _$AccountModelFromJson(json);

@override final  String name;
@override final  String id;
@override final  String avatar;
@override final  DateTime lastUsed;
@override@JsonKey() final  Authentication authMethod;
@override@JsonKey() final  bool askForAuthOnLaunch;
@override@JsonKey() final  String localPin;
@override@CredentialsConverter() final  CredentialsModel credentials;
@override final  SeerrCredentialsModel? seerrCredentials;
@override@JsonKey() final  bool managedIntegrations;
 final  List<String> _latestItemsExcludes;
@override@JsonKey() List<String> get latestItemsExcludes {
  if (_latestItemsExcludes is EqualUnmodifiableListView) return _latestItemsExcludes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_latestItemsExcludes);
}

 final  List<String> _searchQueryHistory;
@override@JsonKey() List<String> get searchQueryHistory {
  if (_searchQueryHistory is EqualUnmodifiableListView) return _searchQueryHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_searchQueryHistory);
}

@override@JsonKey() final  bool quickConnectState;
 final  List<LibraryFiltersModel> _libraryFilters;
@override@JsonKey() List<LibraryFiltersModel> get libraryFilters {
  if (_libraryFilters is EqualUnmodifiableListView) return _libraryFilters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_libraryFilters);
}

@override@JsonKey() final  bool updateNotificationsEnabled;
@override@JsonKey() final  bool seerrRequestsEnabled;
@override@JsonKey() final  bool includeHiddenViews;
@override final  bool? incognitoMode;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  UserPolicy? policy;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  ServerConfiguration? serverConfiguration;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  UserConfiguration? userConfiguration;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  bool? hasPassword;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  bool? hasConfiguredPassword;
@override final  UserSettings? userSettings;

/// Create a copy of AccountModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountModelCopyWith<_AccountModel> get copyWith => __$AccountModelCopyWithImpl<_AccountModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountModelToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'AccountModel'))
    ..add(DiagnosticsProperty('name', name))..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('avatar', avatar))..add(DiagnosticsProperty('lastUsed', lastUsed))..add(DiagnosticsProperty('authMethod', authMethod))..add(DiagnosticsProperty('askForAuthOnLaunch', askForAuthOnLaunch))..add(DiagnosticsProperty('localPin', localPin))..add(DiagnosticsProperty('credentials', credentials))..add(DiagnosticsProperty('seerrCredentials', seerrCredentials))..add(DiagnosticsProperty('managedIntegrations', managedIntegrations))..add(DiagnosticsProperty('latestItemsExcludes', latestItemsExcludes))..add(DiagnosticsProperty('searchQueryHistory', searchQueryHistory))..add(DiagnosticsProperty('quickConnectState', quickConnectState))..add(DiagnosticsProperty('libraryFilters', libraryFilters))..add(DiagnosticsProperty('updateNotificationsEnabled', updateNotificationsEnabled))..add(DiagnosticsProperty('seerrRequestsEnabled', seerrRequestsEnabled))..add(DiagnosticsProperty('includeHiddenViews', includeHiddenViews))..add(DiagnosticsProperty('incognitoMode', incognitoMode))..add(DiagnosticsProperty('policy', policy))..add(DiagnosticsProperty('serverConfiguration', serverConfiguration))..add(DiagnosticsProperty('userConfiguration', userConfiguration))..add(DiagnosticsProperty('hasPassword', hasPassword))..add(DiagnosticsProperty('hasConfiguredPassword', hasConfiguredPassword))..add(DiagnosticsProperty('userSettings', userSettings));
}



@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'AccountModel(name: $name, id: $id, avatar: $avatar, lastUsed: $lastUsed, authMethod: $authMethod, askForAuthOnLaunch: $askForAuthOnLaunch, localPin: $localPin, credentials: $credentials, seerrCredentials: $seerrCredentials, managedIntegrations: $managedIntegrations, latestItemsExcludes: $latestItemsExcludes, searchQueryHistory: $searchQueryHistory, quickConnectState: $quickConnectState, libraryFilters: $libraryFilters, updateNotificationsEnabled: $updateNotificationsEnabled, seerrRequestsEnabled: $seerrRequestsEnabled, includeHiddenViews: $includeHiddenViews, incognitoMode: $incognitoMode, policy: $policy, serverConfiguration: $serverConfiguration, userConfiguration: $userConfiguration, hasPassword: $hasPassword, hasConfiguredPassword: $hasConfiguredPassword, userSettings: $userSettings)';
}


}

/// @nodoc
abstract mixin class _$AccountModelCopyWith<$Res> implements $AccountModelCopyWith<$Res> {
  factory _$AccountModelCopyWith(_AccountModel value, $Res Function(_AccountModel) _then) = __$AccountModelCopyWithImpl;
@override @useResult
$Res call({
 String name, String id, String avatar, DateTime lastUsed, Authentication authMethod, bool askForAuthOnLaunch, String localPin,@CredentialsConverter() CredentialsModel credentials, SeerrCredentialsModel? seerrCredentials, bool managedIntegrations, List<String> latestItemsExcludes, List<String> searchQueryHistory, bool quickConnectState, List<LibraryFiltersModel> libraryFilters, bool updateNotificationsEnabled, bool seerrRequestsEnabled, bool includeHiddenViews, bool? incognitoMode,@JsonKey(includeFromJson: false, includeToJson: false) UserPolicy? policy,@JsonKey(includeFromJson: false, includeToJson: false) ServerConfiguration? serverConfiguration,@JsonKey(includeFromJson: false, includeToJson: false) UserConfiguration? userConfiguration,@JsonKey(includeFromJson: false, includeToJson: false) bool? hasPassword,@JsonKey(includeFromJson: false, includeToJson: false) bool? hasConfiguredPassword, UserSettings? userSettings
});


@override $CredentialsModelCopyWith<$Res> get credentials;@override $SeerrCredentialsModelCopyWith<$Res>? get seerrCredentials;@override $UserSettingsCopyWith<$Res>? get userSettings;

}
/// @nodoc
class __$AccountModelCopyWithImpl<$Res>
    implements _$AccountModelCopyWith<$Res> {
  __$AccountModelCopyWithImpl(this._self, this._then);

  final _AccountModel _self;
  final $Res Function(_AccountModel) _then;

/// Create a copy of AccountModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? id = null,Object? avatar = null,Object? lastUsed = null,Object? authMethod = null,Object? askForAuthOnLaunch = null,Object? localPin = null,Object? credentials = null,Object? seerrCredentials = freezed,Object? managedIntegrations = null,Object? latestItemsExcludes = null,Object? searchQueryHistory = null,Object? quickConnectState = null,Object? libraryFilters = null,Object? updateNotificationsEnabled = null,Object? seerrRequestsEnabled = null,Object? includeHiddenViews = null,Object? incognitoMode = freezed,Object? policy = freezed,Object? serverConfiguration = freezed,Object? userConfiguration = freezed,Object? hasPassword = freezed,Object? hasConfiguredPassword = freezed,Object? userSettings = freezed,}) {
  return _then(_AccountModel(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,avatar: null == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String,lastUsed: null == lastUsed ? _self.lastUsed : lastUsed // ignore: cast_nullable_to_non_nullable
as DateTime,authMethod: null == authMethod ? _self.authMethod : authMethod // ignore: cast_nullable_to_non_nullable
as Authentication,askForAuthOnLaunch: null == askForAuthOnLaunch ? _self.askForAuthOnLaunch : askForAuthOnLaunch // ignore: cast_nullable_to_non_nullable
as bool,localPin: null == localPin ? _self.localPin : localPin // ignore: cast_nullable_to_non_nullable
as String,credentials: null == credentials ? _self.credentials : credentials // ignore: cast_nullable_to_non_nullable
as CredentialsModel,seerrCredentials: freezed == seerrCredentials ? _self.seerrCredentials : seerrCredentials // ignore: cast_nullable_to_non_nullable
as SeerrCredentialsModel?,managedIntegrations: null == managedIntegrations ? _self.managedIntegrations : managedIntegrations // ignore: cast_nullable_to_non_nullable
as bool,latestItemsExcludes: null == latestItemsExcludes ? _self._latestItemsExcludes : latestItemsExcludes // ignore: cast_nullable_to_non_nullable
as List<String>,searchQueryHistory: null == searchQueryHistory ? _self._searchQueryHistory : searchQueryHistory // ignore: cast_nullable_to_non_nullable
as List<String>,quickConnectState: null == quickConnectState ? _self.quickConnectState : quickConnectState // ignore: cast_nullable_to_non_nullable
as bool,libraryFilters: null == libraryFilters ? _self._libraryFilters : libraryFilters // ignore: cast_nullable_to_non_nullable
as List<LibraryFiltersModel>,updateNotificationsEnabled: null == updateNotificationsEnabled ? _self.updateNotificationsEnabled : updateNotificationsEnabled // ignore: cast_nullable_to_non_nullable
as bool,seerrRequestsEnabled: null == seerrRequestsEnabled ? _self.seerrRequestsEnabled : seerrRequestsEnabled // ignore: cast_nullable_to_non_nullable
as bool,includeHiddenViews: null == includeHiddenViews ? _self.includeHiddenViews : includeHiddenViews // ignore: cast_nullable_to_non_nullable
as bool,incognitoMode: freezed == incognitoMode ? _self.incognitoMode : incognitoMode // ignore: cast_nullable_to_non_nullable
as bool?,policy: freezed == policy ? _self.policy : policy // ignore: cast_nullable_to_non_nullable
as UserPolicy?,serverConfiguration: freezed == serverConfiguration ? _self.serverConfiguration : serverConfiguration // ignore: cast_nullable_to_non_nullable
as ServerConfiguration?,userConfiguration: freezed == userConfiguration ? _self.userConfiguration : userConfiguration // ignore: cast_nullable_to_non_nullable
as UserConfiguration?,hasPassword: freezed == hasPassword ? _self.hasPassword : hasPassword // ignore: cast_nullable_to_non_nullable
as bool?,hasConfiguredPassword: freezed == hasConfiguredPassword ? _self.hasConfiguredPassword : hasConfiguredPassword // ignore: cast_nullable_to_non_nullable
as bool?,userSettings: freezed == userSettings ? _self.userSettings : userSettings // ignore: cast_nullable_to_non_nullable
as UserSettings?,
  ));
}

/// Create a copy of AccountModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CredentialsModelCopyWith<$Res> get credentials {
  
  return $CredentialsModelCopyWith<$Res>(_self.credentials, (value) {
    return _then(_self.copyWith(credentials: value));
  });
}/// Create a copy of AccountModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SeerrCredentialsModelCopyWith<$Res>? get seerrCredentials {
    if (_self.seerrCredentials == null) {
    return null;
  }

  return $SeerrCredentialsModelCopyWith<$Res>(_self.seerrCredentials!, (value) {
    return _then(_self.copyWith(seerrCredentials: value));
  });
}/// Create a copy of AccountModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSettingsCopyWith<$Res>? get userSettings {
    if (_self.userSettings == null) {
    return null;
  }

  return $UserSettingsCopyWith<$Res>(_self.userSettings!, (value) {
    return _then(_self.copyWith(userSettings: value));
  });
}
}


/// @nodoc
mixin _$UserSettings implements DiagnosticableTreeMixin {

 Duration get skipForwardDuration; Duration get skipBackDuration; String? get syncedAt; String? get seerrServerUrl; bool? get seerrRequestsEnabled; String? get homeBanner; String? get homeCarousel; String? get homeNextUp; List<String>? get pinnedCollectionIds; String? get themeMode; String? get themeColor; String? get schemeVariant; bool? get amoledBlack; bool? get deriveColorsFromItem; String? get backgroundImage; bool? get enableBlurEffects; bool? get blurPlaceHolders; double? get posterSize; String? get locale; bool? get showAllCollectionTypes; bool? get usePosterForLibrary;@LibraryFiltersConverter() List<LibraryFiltersModel> get libraryFilters;@FilterSortOrderConverter() Map<FilterSortKey, List<String>> get filterSortOrder;@DashboardSortingConverter() Map<DashboardSorting, bool> get pDashboardSorting;
/// Create a copy of UserSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserSettingsCopyWith<UserSettings> get copyWith => _$UserSettingsCopyWithImpl<UserSettings>(this as UserSettings, _$identity);

  /// Serializes this UserSettings to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as UserSettings;
  properties
    ..add(DiagnosticsProperty('type', 'UserSettings'))
    ..add(DiagnosticsProperty('skipForwardDuration', _this.skipForwardDuration))..add(DiagnosticsProperty('skipBackDuration', _this.skipBackDuration))..add(DiagnosticsProperty('syncedAt', _this.syncedAt))..add(DiagnosticsProperty('seerrServerUrl', _this.seerrServerUrl))..add(DiagnosticsProperty('seerrRequestsEnabled', _this.seerrRequestsEnabled))..add(DiagnosticsProperty('homeBanner', _this.homeBanner))..add(DiagnosticsProperty('homeCarousel', _this.homeCarousel))..add(DiagnosticsProperty('homeNextUp', _this.homeNextUp))..add(DiagnosticsProperty('pinnedCollectionIds', _this.pinnedCollectionIds))..add(DiagnosticsProperty('themeMode', _this.themeMode))..add(DiagnosticsProperty('themeColor', _this.themeColor))..add(DiagnosticsProperty('schemeVariant', _this.schemeVariant))..add(DiagnosticsProperty('amoledBlack', _this.amoledBlack))..add(DiagnosticsProperty('deriveColorsFromItem', _this.deriveColorsFromItem))..add(DiagnosticsProperty('backgroundImage', _this.backgroundImage))..add(DiagnosticsProperty('enableBlurEffects', _this.enableBlurEffects))..add(DiagnosticsProperty('blurPlaceHolders', _this.blurPlaceHolders))..add(DiagnosticsProperty('posterSize', _this.posterSize))..add(DiagnosticsProperty('locale', _this.locale))..add(DiagnosticsProperty('showAllCollectionTypes', _this.showAllCollectionTypes))..add(DiagnosticsProperty('usePosterForLibrary', _this.usePosterForLibrary))..add(DiagnosticsProperty('libraryFilters', _this.libraryFilters))..add(DiagnosticsProperty('filterSortOrder', _this.filterSortOrder))..add(DiagnosticsProperty('pDashboardSorting', _this.pDashboardSorting));
}



@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as UserSettings;
  return 'UserSettings(skipForwardDuration: ${_this.skipForwardDuration}, skipBackDuration: ${_this.skipBackDuration}, syncedAt: ${_this.syncedAt}, seerrServerUrl: ${_this.seerrServerUrl}, seerrRequestsEnabled: ${_this.seerrRequestsEnabled}, homeBanner: ${_this.homeBanner}, homeCarousel: ${_this.homeCarousel}, homeNextUp: ${_this.homeNextUp}, pinnedCollectionIds: ${_this.pinnedCollectionIds}, themeMode: ${_this.themeMode}, themeColor: ${_this.themeColor}, schemeVariant: ${_this.schemeVariant}, amoledBlack: ${_this.amoledBlack}, deriveColorsFromItem: ${_this.deriveColorsFromItem}, backgroundImage: ${_this.backgroundImage}, enableBlurEffects: ${_this.enableBlurEffects}, blurPlaceHolders: ${_this.blurPlaceHolders}, posterSize: ${_this.posterSize}, locale: ${_this.locale}, showAllCollectionTypes: ${_this.showAllCollectionTypes}, usePosterForLibrary: ${_this.usePosterForLibrary}, libraryFilters: ${_this.libraryFilters}, filterSortOrder: ${_this.filterSortOrder}, pDashboardSorting: ${_this.pDashboardSorting})';
}


}

/// @nodoc
abstract mixin class $UserSettingsCopyWith<$Res>  {
  factory $UserSettingsCopyWith(UserSettings value, $Res Function(UserSettings) _then) = _$UserSettingsCopyWithImpl;
@useResult
$Res call({
 Duration skipForwardDuration, Duration skipBackDuration, String? syncedAt, String? seerrServerUrl, bool? seerrRequestsEnabled, String? homeBanner, String? homeCarousel, String? homeNextUp, List<String>? pinnedCollectionIds, String? themeMode, String? themeColor, String? schemeVariant, bool? amoledBlack, bool? deriveColorsFromItem, String? backgroundImage, bool? enableBlurEffects, bool? blurPlaceHolders, double? posterSize, String? locale, bool? showAllCollectionTypes, bool? usePosterForLibrary,@LibraryFiltersConverter() List<LibraryFiltersModel> libraryFilters,@FilterSortOrderConverter() Map<FilterSortKey, List<String>> filterSortOrder,@DashboardSortingConverter() Map<DashboardSorting, bool> pDashboardSorting
});




}
/// @nodoc
class _$UserSettingsCopyWithImpl<$Res>
    implements $UserSettingsCopyWith<$Res> {
  _$UserSettingsCopyWithImpl(this._self, this._then);

  final UserSettings _self;
  final $Res Function(UserSettings) _then;

/// Create a copy of UserSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? skipForwardDuration = null,Object? skipBackDuration = null,Object? syncedAt = freezed,Object? seerrServerUrl = freezed,Object? seerrRequestsEnabled = freezed,Object? homeBanner = freezed,Object? homeCarousel = freezed,Object? homeNextUp = freezed,Object? pinnedCollectionIds = freezed,Object? themeMode = freezed,Object? themeColor = freezed,Object? schemeVariant = freezed,Object? amoledBlack = freezed,Object? deriveColorsFromItem = freezed,Object? backgroundImage = freezed,Object? enableBlurEffects = freezed,Object? blurPlaceHolders = freezed,Object? posterSize = freezed,Object? locale = freezed,Object? showAllCollectionTypes = freezed,Object? usePosterForLibrary = freezed,Object? libraryFilters = null,Object? filterSortOrder = null,Object? pDashboardSorting = null,}) {
  return _then(UserSettings(
skipForwardDuration: null == skipForwardDuration ? _self.skipForwardDuration : skipForwardDuration // ignore: cast_nullable_to_non_nullable
as Duration,skipBackDuration: null == skipBackDuration ? _self.skipBackDuration : skipBackDuration // ignore: cast_nullable_to_non_nullable
as Duration,syncedAt: freezed == syncedAt ? _self.syncedAt : syncedAt // ignore: cast_nullable_to_non_nullable
as String?,seerrServerUrl: freezed == seerrServerUrl ? _self.seerrServerUrl : seerrServerUrl // ignore: cast_nullable_to_non_nullable
as String?,seerrRequestsEnabled: freezed == seerrRequestsEnabled ? _self.seerrRequestsEnabled : seerrRequestsEnabled // ignore: cast_nullable_to_non_nullable
as bool?,homeBanner: freezed == homeBanner ? _self.homeBanner : homeBanner // ignore: cast_nullable_to_non_nullable
as String?,homeCarousel: freezed == homeCarousel ? _self.homeCarousel : homeCarousel // ignore: cast_nullable_to_non_nullable
as String?,homeNextUp: freezed == homeNextUp ? _self.homeNextUp : homeNextUp // ignore: cast_nullable_to_non_nullable
as String?,pinnedCollectionIds: freezed == pinnedCollectionIds ? _self.pinnedCollectionIds : pinnedCollectionIds // ignore: cast_nullable_to_non_nullable
as List<String>?,themeMode: freezed == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as String?,themeColor: freezed == themeColor ? _self.themeColor : themeColor // ignore: cast_nullable_to_non_nullable
as String?,schemeVariant: freezed == schemeVariant ? _self.schemeVariant : schemeVariant // ignore: cast_nullable_to_non_nullable
as String?,amoledBlack: freezed == amoledBlack ? _self.amoledBlack : amoledBlack // ignore: cast_nullable_to_non_nullable
as bool?,deriveColorsFromItem: freezed == deriveColorsFromItem ? _self.deriveColorsFromItem : deriveColorsFromItem // ignore: cast_nullable_to_non_nullable
as bool?,backgroundImage: freezed == backgroundImage ? _self.backgroundImage : backgroundImage // ignore: cast_nullable_to_non_nullable
as String?,enableBlurEffects: freezed == enableBlurEffects ? _self.enableBlurEffects : enableBlurEffects // ignore: cast_nullable_to_non_nullable
as bool?,blurPlaceHolders: freezed == blurPlaceHolders ? _self.blurPlaceHolders : blurPlaceHolders // ignore: cast_nullable_to_non_nullable
as bool?,posterSize: freezed == posterSize ? _self.posterSize : posterSize // ignore: cast_nullable_to_non_nullable
as double?,locale: freezed == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String?,showAllCollectionTypes: freezed == showAllCollectionTypes ? _self.showAllCollectionTypes : showAllCollectionTypes // ignore: cast_nullable_to_non_nullable
as bool?,usePosterForLibrary: freezed == usePosterForLibrary ? _self.usePosterForLibrary : usePosterForLibrary // ignore: cast_nullable_to_non_nullable
as bool?,libraryFilters: null == libraryFilters ? _self.libraryFilters : libraryFilters // ignore: cast_nullable_to_non_nullable
as List<LibraryFiltersModel>,filterSortOrder: null == filterSortOrder ? _self.filterSortOrder : filterSortOrder // ignore: cast_nullable_to_non_nullable
as Map<FilterSortKey, List<String>>,pDashboardSorting: null == pDashboardSorting ? _self.pDashboardSorting : pDashboardSorting // ignore: cast_nullable_to_non_nullable
as Map<DashboardSorting, bool>,
  ));
}

}


/// Adds pattern-matching-related methods to [UserSettings].
extension UserSettingsPatterns on UserSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserSettings() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserSettings value)  $default,){
final _that = this;
switch (_that) {
case _UserSettings():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserSettings value)?  $default,){
final _that = this;
switch (_that) {
case _UserSettings() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Duration skipForwardDuration,  Duration skipBackDuration,  String? syncedAt,  String? seerrServerUrl,  bool? seerrRequestsEnabled,  String? homeBanner,  String? homeCarousel,  String? homeNextUp,  List<String>? pinnedCollectionIds,  String? themeMode,  String? themeColor,  String? schemeVariant,  bool? amoledBlack,  bool? deriveColorsFromItem,  String? backgroundImage,  bool? enableBlurEffects,  bool? blurPlaceHolders,  double? posterSize,  String? locale,  bool? showAllCollectionTypes,  bool? usePosterForLibrary, @LibraryFiltersConverter()  List<LibraryFiltersModel> libraryFilters, @FilterSortOrderConverter()  Map<FilterSortKey, List<String>> filterSortOrder, @DashboardSortingConverter()  Map<DashboardSorting, bool> pDashboardSorting)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserSettings() when $default != null:
return $default(_that.skipForwardDuration,_that.skipBackDuration,_that.syncedAt,_that.seerrServerUrl,_that.seerrRequestsEnabled,_that.homeBanner,_that.homeCarousel,_that.homeNextUp,_that.pinnedCollectionIds,_that.themeMode,_that.themeColor,_that.schemeVariant,_that.amoledBlack,_that.deriveColorsFromItem,_that.backgroundImage,_that.enableBlurEffects,_that.blurPlaceHolders,_that.posterSize,_that.locale,_that.showAllCollectionTypes,_that.usePosterForLibrary,_that.libraryFilters,_that.filterSortOrder,_that.pDashboardSorting);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Duration skipForwardDuration,  Duration skipBackDuration,  String? syncedAt,  String? seerrServerUrl,  bool? seerrRequestsEnabled,  String? homeBanner,  String? homeCarousel,  String? homeNextUp,  List<String>? pinnedCollectionIds,  String? themeMode,  String? themeColor,  String? schemeVariant,  bool? amoledBlack,  bool? deriveColorsFromItem,  String? backgroundImage,  bool? enableBlurEffects,  bool? blurPlaceHolders,  double? posterSize,  String? locale,  bool? showAllCollectionTypes,  bool? usePosterForLibrary, @LibraryFiltersConverter()  List<LibraryFiltersModel> libraryFilters, @FilterSortOrderConverter()  Map<FilterSortKey, List<String>> filterSortOrder, @DashboardSortingConverter()  Map<DashboardSorting, bool> pDashboardSorting)  $default,) {final _that = this;
switch (_that) {
case _UserSettings():
return $default(_that.skipForwardDuration,_that.skipBackDuration,_that.syncedAt,_that.seerrServerUrl,_that.seerrRequestsEnabled,_that.homeBanner,_that.homeCarousel,_that.homeNextUp,_that.pinnedCollectionIds,_that.themeMode,_that.themeColor,_that.schemeVariant,_that.amoledBlack,_that.deriveColorsFromItem,_that.backgroundImage,_that.enableBlurEffects,_that.blurPlaceHolders,_that.posterSize,_that.locale,_that.showAllCollectionTypes,_that.usePosterForLibrary,_that.libraryFilters,_that.filterSortOrder,_that.pDashboardSorting);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Duration skipForwardDuration,  Duration skipBackDuration,  String? syncedAt,  String? seerrServerUrl,  bool? seerrRequestsEnabled,  String? homeBanner,  String? homeCarousel,  String? homeNextUp,  List<String>? pinnedCollectionIds,  String? themeMode,  String? themeColor,  String? schemeVariant,  bool? amoledBlack,  bool? deriveColorsFromItem,  String? backgroundImage,  bool? enableBlurEffects,  bool? blurPlaceHolders,  double? posterSize,  String? locale,  bool? showAllCollectionTypes,  bool? usePosterForLibrary, @LibraryFiltersConverter()  List<LibraryFiltersModel> libraryFilters, @FilterSortOrderConverter()  Map<FilterSortKey, List<String>> filterSortOrder, @DashboardSortingConverter()  Map<DashboardSorting, bool> pDashboardSorting)?  $default,) {final _that = this;
switch (_that) {
case _UserSettings() when $default != null:
return $default(_that.skipForwardDuration,_that.skipBackDuration,_that.syncedAt,_that.seerrServerUrl,_that.seerrRequestsEnabled,_that.homeBanner,_that.homeCarousel,_that.homeNextUp,_that.pinnedCollectionIds,_that.themeMode,_that.themeColor,_that.schemeVariant,_that.amoledBlack,_that.deriveColorsFromItem,_that.backgroundImage,_that.enableBlurEffects,_that.blurPlaceHolders,_that.posterSize,_that.locale,_that.showAllCollectionTypes,_that.usePosterForLibrary,_that.libraryFilters,_that.filterSortOrder,_that.pDashboardSorting);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserSettings extends UserSettings with DiagnosticableTreeMixin {
   _UserSettings({this.skipForwardDuration = const Duration(seconds: 30), this.skipBackDuration = const Duration(seconds: 10), this.syncedAt, this.seerrServerUrl, this.seerrRequestsEnabled, this.homeBanner, this.homeCarousel, this.homeNextUp,  List<String>? pinnedCollectionIds, this.themeMode, this.themeColor, this.schemeVariant, this.amoledBlack, this.deriveColorsFromItem, this.backgroundImage, this.enableBlurEffects, this.blurPlaceHolders, this.posterSize, this.locale, this.showAllCollectionTypes, this.usePosterForLibrary, @LibraryFiltersConverter()  List<LibraryFiltersModel> libraryFilters = const [], @FilterSortOrderConverter()  Map<FilterSortKey, List<String>> filterSortOrder = const {}, @DashboardSortingConverter()  Map<DashboardSorting, bool> pDashboardSorting = const {}}): _pinnedCollectionIds = pinnedCollectionIds,_libraryFilters = libraryFilters,_filterSortOrder = filterSortOrder,_pDashboardSorting = pDashboardSorting,super._();
  factory _UserSettings.fromJson(Map<String, dynamic> json) => _$UserSettingsFromJson(json);

@override@JsonKey() final  Duration skipForwardDuration;
@override@JsonKey() final  Duration skipBackDuration;
@override final  String? syncedAt;
@override final  String? seerrServerUrl;
@override final  bool? seerrRequestsEnabled;
@override final  String? homeBanner;
@override final  String? homeCarousel;
@override final  String? homeNextUp;
 final  List<String>? _pinnedCollectionIds;
@override List<String>? get pinnedCollectionIds {
  final value = _pinnedCollectionIds;
  if (value == null) return null;
  if (_pinnedCollectionIds is EqualUnmodifiableListView) return _pinnedCollectionIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? themeMode;
@override final  String? themeColor;
@override final  String? schemeVariant;
@override final  bool? amoledBlack;
@override final  bool? deriveColorsFromItem;
@override final  String? backgroundImage;
@override final  bool? enableBlurEffects;
@override final  bool? blurPlaceHolders;
@override final  double? posterSize;
@override final  String? locale;
@override final  bool? showAllCollectionTypes;
@override final  bool? usePosterForLibrary;
 final  List<LibraryFiltersModel> _libraryFilters;
@override@JsonKey()@LibraryFiltersConverter() List<LibraryFiltersModel> get libraryFilters {
  if (_libraryFilters is EqualUnmodifiableListView) return _libraryFilters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_libraryFilters);
}

 final  Map<FilterSortKey, List<String>> _filterSortOrder;
@override@JsonKey()@FilterSortOrderConverter() Map<FilterSortKey, List<String>> get filterSortOrder {
  if (_filterSortOrder is EqualUnmodifiableMapView) return _filterSortOrder;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_filterSortOrder);
}

 final  Map<DashboardSorting, bool> _pDashboardSorting;
@override@JsonKey()@DashboardSortingConverter() Map<DashboardSorting, bool> get pDashboardSorting {
  if (_pDashboardSorting is EqualUnmodifiableMapView) return _pDashboardSorting;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_pDashboardSorting);
}


/// Create a copy of UserSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserSettingsCopyWith<_UserSettings> get copyWith => __$UserSettingsCopyWithImpl<_UserSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserSettingsToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'UserSettings'))
    ..add(DiagnosticsProperty('skipForwardDuration', skipForwardDuration))..add(DiagnosticsProperty('skipBackDuration', skipBackDuration))..add(DiagnosticsProperty('syncedAt', syncedAt))..add(DiagnosticsProperty('seerrServerUrl', seerrServerUrl))..add(DiagnosticsProperty('seerrRequestsEnabled', seerrRequestsEnabled))..add(DiagnosticsProperty('homeBanner', homeBanner))..add(DiagnosticsProperty('homeCarousel', homeCarousel))..add(DiagnosticsProperty('homeNextUp', homeNextUp))..add(DiagnosticsProperty('pinnedCollectionIds', pinnedCollectionIds))..add(DiagnosticsProperty('themeMode', themeMode))..add(DiagnosticsProperty('themeColor', themeColor))..add(DiagnosticsProperty('schemeVariant', schemeVariant))..add(DiagnosticsProperty('amoledBlack', amoledBlack))..add(DiagnosticsProperty('deriveColorsFromItem', deriveColorsFromItem))..add(DiagnosticsProperty('backgroundImage', backgroundImage))..add(DiagnosticsProperty('enableBlurEffects', enableBlurEffects))..add(DiagnosticsProperty('blurPlaceHolders', blurPlaceHolders))..add(DiagnosticsProperty('posterSize', posterSize))..add(DiagnosticsProperty('locale', locale))..add(DiagnosticsProperty('showAllCollectionTypes', showAllCollectionTypes))..add(DiagnosticsProperty('usePosterForLibrary', usePosterForLibrary))..add(DiagnosticsProperty('libraryFilters', libraryFilters))..add(DiagnosticsProperty('filterSortOrder', filterSortOrder))..add(DiagnosticsProperty('pDashboardSorting', pDashboardSorting));
}



@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'UserSettings(skipForwardDuration: $skipForwardDuration, skipBackDuration: $skipBackDuration, syncedAt: $syncedAt, seerrServerUrl: $seerrServerUrl, seerrRequestsEnabled: $seerrRequestsEnabled, homeBanner: $homeBanner, homeCarousel: $homeCarousel, homeNextUp: $homeNextUp, pinnedCollectionIds: $pinnedCollectionIds, themeMode: $themeMode, themeColor: $themeColor, schemeVariant: $schemeVariant, amoledBlack: $amoledBlack, deriveColorsFromItem: $deriveColorsFromItem, backgroundImage: $backgroundImage, enableBlurEffects: $enableBlurEffects, blurPlaceHolders: $blurPlaceHolders, posterSize: $posterSize, locale: $locale, showAllCollectionTypes: $showAllCollectionTypes, usePosterForLibrary: $usePosterForLibrary, libraryFilters: $libraryFilters, filterSortOrder: $filterSortOrder, pDashboardSorting: $pDashboardSorting)';
}


}

/// @nodoc
abstract mixin class _$UserSettingsCopyWith<$Res> implements $UserSettingsCopyWith<$Res> {
  factory _$UserSettingsCopyWith(_UserSettings value, $Res Function(_UserSettings) _then) = __$UserSettingsCopyWithImpl;
@override @useResult
$Res call({
 Duration skipForwardDuration, Duration skipBackDuration, String? syncedAt, String? seerrServerUrl, bool? seerrRequestsEnabled, String? homeBanner, String? homeCarousel, String? homeNextUp, List<String>? pinnedCollectionIds, String? themeMode, String? themeColor, String? schemeVariant, bool? amoledBlack, bool? deriveColorsFromItem, String? backgroundImage, bool? enableBlurEffects, bool? blurPlaceHolders, double? posterSize, String? locale, bool? showAllCollectionTypes, bool? usePosterForLibrary,@LibraryFiltersConverter() List<LibraryFiltersModel> libraryFilters,@FilterSortOrderConverter() Map<FilterSortKey, List<String>> filterSortOrder,@DashboardSortingConverter() Map<DashboardSorting, bool> pDashboardSorting
});




}
/// @nodoc
class __$UserSettingsCopyWithImpl<$Res>
    implements _$UserSettingsCopyWith<$Res> {
  __$UserSettingsCopyWithImpl(this._self, this._then);

  final _UserSettings _self;
  final $Res Function(_UserSettings) _then;

/// Create a copy of UserSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? skipForwardDuration = null,Object? skipBackDuration = null,Object? syncedAt = freezed,Object? seerrServerUrl = freezed,Object? seerrRequestsEnabled = freezed,Object? homeBanner = freezed,Object? homeCarousel = freezed,Object? homeNextUp = freezed,Object? pinnedCollectionIds = freezed,Object? themeMode = freezed,Object? themeColor = freezed,Object? schemeVariant = freezed,Object? amoledBlack = freezed,Object? deriveColorsFromItem = freezed,Object? backgroundImage = freezed,Object? enableBlurEffects = freezed,Object? blurPlaceHolders = freezed,Object? posterSize = freezed,Object? locale = freezed,Object? showAllCollectionTypes = freezed,Object? usePosterForLibrary = freezed,Object? libraryFilters = null,Object? filterSortOrder = null,Object? pDashboardSorting = null,}) {
  return _then(_UserSettings(
skipForwardDuration: null == skipForwardDuration ? _self.skipForwardDuration : skipForwardDuration // ignore: cast_nullable_to_non_nullable
as Duration,skipBackDuration: null == skipBackDuration ? _self.skipBackDuration : skipBackDuration // ignore: cast_nullable_to_non_nullable
as Duration,syncedAt: freezed == syncedAt ? _self.syncedAt : syncedAt // ignore: cast_nullable_to_non_nullable
as String?,seerrServerUrl: freezed == seerrServerUrl ? _self.seerrServerUrl : seerrServerUrl // ignore: cast_nullable_to_non_nullable
as String?,seerrRequestsEnabled: freezed == seerrRequestsEnabled ? _self.seerrRequestsEnabled : seerrRequestsEnabled // ignore: cast_nullable_to_non_nullable
as bool?,homeBanner: freezed == homeBanner ? _self.homeBanner : homeBanner // ignore: cast_nullable_to_non_nullable
as String?,homeCarousel: freezed == homeCarousel ? _self.homeCarousel : homeCarousel // ignore: cast_nullable_to_non_nullable
as String?,homeNextUp: freezed == homeNextUp ? _self.homeNextUp : homeNextUp // ignore: cast_nullable_to_non_nullable
as String?,pinnedCollectionIds: freezed == pinnedCollectionIds ? _self._pinnedCollectionIds : pinnedCollectionIds // ignore: cast_nullable_to_non_nullable
as List<String>?,themeMode: freezed == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as String?,themeColor: freezed == themeColor ? _self.themeColor : themeColor // ignore: cast_nullable_to_non_nullable
as String?,schemeVariant: freezed == schemeVariant ? _self.schemeVariant : schemeVariant // ignore: cast_nullable_to_non_nullable
as String?,amoledBlack: freezed == amoledBlack ? _self.amoledBlack : amoledBlack // ignore: cast_nullable_to_non_nullable
as bool?,deriveColorsFromItem: freezed == deriveColorsFromItem ? _self.deriveColorsFromItem : deriveColorsFromItem // ignore: cast_nullable_to_non_nullable
as bool?,backgroundImage: freezed == backgroundImage ? _self.backgroundImage : backgroundImage // ignore: cast_nullable_to_non_nullable
as String?,enableBlurEffects: freezed == enableBlurEffects ? _self.enableBlurEffects : enableBlurEffects // ignore: cast_nullable_to_non_nullable
as bool?,blurPlaceHolders: freezed == blurPlaceHolders ? _self.blurPlaceHolders : blurPlaceHolders // ignore: cast_nullable_to_non_nullable
as bool?,posterSize: freezed == posterSize ? _self.posterSize : posterSize // ignore: cast_nullable_to_non_nullable
as double?,locale: freezed == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String?,showAllCollectionTypes: freezed == showAllCollectionTypes ? _self.showAllCollectionTypes : showAllCollectionTypes // ignore: cast_nullable_to_non_nullable
as bool?,usePosterForLibrary: freezed == usePosterForLibrary ? _self.usePosterForLibrary : usePosterForLibrary // ignore: cast_nullable_to_non_nullable
as bool?,libraryFilters: null == libraryFilters ? _self._libraryFilters : libraryFilters // ignore: cast_nullable_to_non_nullable
as List<LibraryFiltersModel>,filterSortOrder: null == filterSortOrder ? _self._filterSortOrder : filterSortOrder // ignore: cast_nullable_to_non_nullable
as Map<FilterSortKey, List<String>>,pDashboardSorting: null == pDashboardSorting ? _self._pDashboardSorting : pDashboardSorting // ignore: cast_nullable_to_non_nullable
as Map<DashboardSorting, bool>,
  ));
}


}

// dart format on
