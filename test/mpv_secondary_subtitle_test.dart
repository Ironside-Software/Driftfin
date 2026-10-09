import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/models/items/media_streams_model.dart';
import 'package:driftfin/wrappers/players/mpv_secondary_subtitle.dart';

SubStreamModel subtitle(int index, {bool external = false, String? url}) => SubStreamModel(
  name: 'Subtitle $index',
  id: '$index',
  title: 'Subtitle $index',
  displayTitle: 'Subtitle $index',
  language: 'en',
  codec: 'srt',
  isDefault: false,
  isExternal: external,
  index: index,
  url: url,
);

void main() {
  late Map<String, String> properties;
  late List<List<String>> commands;
  late List<(String, String)> writes;

  setUp(() {
    properties = {};
    commands = [];
    writes = [];
  });

  Future<int> select(SubStreamModel? track, {List<SubStreamModel>? streams, List<String>? ids}) =>
      selectMpvSecondarySubtitle(
        subtitle: track,
        streams: streams ?? [],
        embeddedTrackIds: ids ?? [],
        getProperty: (name) async => properties[name] ?? '',
        setProperty: (name, value) async => writes.add((name, value)),
        command: (args) async {
          commands.add(args);
          properties.addAll({
            'track-list/count': '1',
            'track-list/0/type': 'sub',
            'track-list/0/external-filename': args[1],
            'track-list/0/id': '17',
          });
        },
      );

  test('Off disables the secondary track only', () async {
    expect(await select(null), -1);
    expect(await select(SubStreamModel.no()), -1);
    expect(writes, [('secondary-sid', 'no'), ('secondary-sid', 'no')]);
    expect(commands, isEmpty);
  });

  test('maps embedded subtitle order to mpv IDs, ignoring external streams and Off', () async {
    final first = subtitle(5);
    final second = subtitle(9);
    expect(
      await select(second, streams: [SubStreamModel.no(), subtitle(2, external: true), first, second], ids: ['3', '8']),
      9,
    );
    expect(writes, [('secondary-sid', '8')]);
  });

  test('loads an external subtitle without selecting it as primary, and reuses it', () async {
    final track = subtitle(12, external: true, url: 'https://server/sub.srt?token=example');
    expect(await select(track), 12);
    expect(commands, [
      ['sub-add', track.url, 'auto'],
    ]);
    expect(writes, [('secondary-sid', '17')]);
    expect(await select(track), 12);
    expect(commands, hasLength(1));
  });

  test('unavailable tracks fail without changing the selected secondary track', () async {
    await expectLater(select(subtitle(7), streams: [subtitle(7)]), throwsStateError);
    await expectLater(select(subtitle(8, external: true)), throwsStateError);
    expect(writes, isEmpty);
    expect(commands, isEmpty);
  });
}
