import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/settings/settings_list_tile.dart';
import 'package:driftfin/screens/settings/widgets/settings_backup_actions.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';

const _adaptiveModel = AdaptiveLayoutModel(
  viewSize: ViewSize.phone,
  layoutMode: LayoutMode.single,
  inputDevice: InputDevice.touch,
  platform: TargetPlatform.android,
  isDesktop: false,
  posterDefaults: PosterDefaults(size: 100, ratio: 0.66),
  controller: <HomeTabs, ScrollController>{},
  sideBarWidth: 0,
  topBarHeight: 0,
  statusBarHeight: 0,
);

class _FakeFilePicker extends FilePickerPlatform with MockPlatformInterfaceMixin {
  Uint8List? saveFileBytes;
  bool saveFileCalled = false;
  Uri? saveFileReturn;
  PlatformFile? pickFilesReturn;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    saveFileCalled = true;
    saveFileBytes = bytes;
    return saveFileReturn;
  }

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => pickFilesReturn;
}

final class _MemoryFile extends PlatformFile {
  _MemoryFile(this.bytes);
  final Uint8List bytes;
  @override
  String get name => 'driftfin-settings.json';
  @override
  Uri get uri => Uri.parse('memory:settings.json');
  @override
  Never get xFile => throw UnimplementedError();
  @override
  int lengthSync() => bytes.length;
  @override
  Future<int> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

class _FakeUser extends User {
  _FakeUser(this._initial);
  final AccountModel? _initial;

  @override
  AccountModel? build() => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;
  late _FakeFilePicker fakePicker;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // No real platform plugin is registered under `flutter test`, so install a
    // fake for the whole file (each test file runs in its own isolate).
    fakePicker = _FakeFilePicker();
    FilePickerPlatform.instance = fakePicker;
  });

  setUp(() {
    fakePicker
      ..saveFileBytes = null
      ..saveFileCalled = false
      ..saveFileReturn = null
      ..pickFilesReturn = null;
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userProvider.overrideWith(() => _FakeUser(null)),
        ],
        // AdaptiveLayout sits ABOVE MaterialApp (as it does in the real app) so
        // the FladderSnack overlay — inserted into MaterialApp's Overlay — can
        // still resolve AdaptiveLayout.viewSizeOf/inputDeviceOf.
        child: const AdaptiveLayout(
          data: _adaptiveModel,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SettingsBackupActions()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(SettingsBackupActions)));
  }

  SettingsListTile tileFor(WidgetTester tester, String label) => tester
      .widgetList<SettingsListTile>(find.byType(SettingsListTile))
      .firstWhere((t) => (t.label as Text).data == label);

  // Fire the FladderSnack's 5s auto-dismiss timer and its reverse animation so
  // no timer/overlay outlives the test.
  Future<void> drainSnack(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('renders export, import and reset tiles', (tester) async {
    await pump(tester);
    expect(find.text(l10n.settingsExportSettingsTitle), findsOneWidget);
    expect(find.text(l10n.settingsImportSettingsTitle), findsOneWidget);
    expect(find.text(l10n.clearAllSettings), findsOneWidget);
  });

  testWidgets('export always passes bytes to saveFile', (tester) async {
    // Regression guard: Android & iOS throw if saveFile is called without
    // bytes, so export must supply them on every platform (not just web).
    // Cancelling skips the success snackbar; the picker still receives the bytes.
    await pump(tester);
    await tileFor(tester, l10n.settingsExportSettingsTitle).onTap!();
    await tester.pump();

    expect(fakePicker.saveFileCalled, isTrue);
    expect(fakePicker.saveFileBytes, isNotNull, reason: 'export must pass bytes (required on Android/iOS)');
    // The bytes are the serialized settings payload.
    final decoded = jsonDecode(utf8.decode(fakePicker.saveFileBytes!));
    expect(decoded, isA<Map<String, dynamic>>());
  });

  testWidgets('export lets the picker persist bytes without a second file write', (tester) async {
    fakePicker.saveFileReturn = Uri.parse('content://documents/settings.json');
    await pump(tester);
    await tileFor(tester, l10n.settingsExportSettingsTitle).onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(fakePicker.saveFileBytes, isNotEmpty);
    expect(find.text(l10n.saved), findsOneWidget);
    expect(tester.takeException(), isNull);
    await drainSnack(tester);
  });

  testWidgets('import reads a chosen JSON file and applies it', (tester) async {
    final payload = utf8.encode(jsonEncode(UserSettings().toJson()));
    fakePicker.pickFilesReturn = _MemoryFile(Uint8List.fromList(payload));

    await pump(tester);
    await tileFor(tester, l10n.settingsImportSettingsTitle).onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350)); // let the snack fade in

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.saved), findsOneWidget);

    await drainSnack(tester);
  });

  testWidgets('export and import take the cancelled path without throwing', (tester) async {
    // saveFileReturn / pickFilesReturn stay null => user cancelled.
    await pump(tester);

    await tileFor(tester, l10n.settingsExportSettingsTitle).onTap!();
    await tester.pumpAndSettle();
    await tileFor(tester, l10n.settingsImportSettingsTitle).onTap!();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('reset shows a confirmation dialog that can be cancelled', (tester) async {
    await pump(tester);

    tileFor(tester, l10n.clearAllSettings).onTap!();
    await tester.pumpAndSettle();

    expect(find.text(l10n.clearAllSettingsQuestion), findsOneWidget);
    expect(find.text(l10n.unableToReverseAction), findsOneWidget);

    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();

    expect(find.text(l10n.clearAllSettingsQuestion), findsNothing);
  });
}
