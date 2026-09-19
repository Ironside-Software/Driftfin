import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart' as dl;
import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/models/items/chapters_model.dart';
import 'package:driftfin/models/items/images_models.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/items/trick_play_model.dart';
import 'package:driftfin/models/syncing/sync_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// deleteDatFiles takes a Ref but never reads it; a throwaway container is
/// enough to obtain a real, cheap Ref instance without any provider wiring.
Ref _dummyRef() {
  final container = ProviderContainer();
  final refProvider = Provider<Ref>((ref) => ref);
  return container.read(refProvider);
}

SyncedItem _syncedItem({
  required String path,
  String id = 'item1',
  String? videoFileName,
  int? fileSize,
  ImagesData? fImages,
  TrickPlayModel? fTrickPlayModel,
  UserData? userData,
}) =>
    SyncedItem(
      id: id,
      userId: 'user1',
      path: path,
      videoFileName: videoFileName,
      fileSize: fileSize,
      fImages: fImages,
      fTrickPlayModel: fTrickPlayModel,
      userData: userData,
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('synced_item_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('file location getters', () {
    test('videoFile, dataFile, overlayFile and directory resolve under path', () {
      final item = _syncedItem(path: tempDir.path, videoFileName: 'movie.mp4');
      expect(item.videoFile.path, p.join(tempDir.path, 'movie.mp4'));
      expect(item.dataFile.path, p.join(tempDir.path, 'data.json'));
      expect(item.overlayFile.path, p.join(tempDir.path, 'overlay.json'));
      expect(item.directory.path, tempDir.path);
    });

    test('directory defaults to empty string path when path is null', () {
      final item = _syncedItem(path: '');
      final noPath = item.copyWith(path: null);
      expect(noPath.directory.path, '');
    });
  });

  group('status', () {
    test('complete once the video file exists', () {
      final videoFile = File(p.join(tempDir.path, 'movie.mp4'))..createSync();
      final item = _syncedItem(path: tempDir.path, videoFileName: 'movie.mp4');
      expect(videoFile.existsSync(), isTrue);
      expect(item.status, dl.TaskStatus.complete);
    });

    test('notFound when the video file is missing', () {
      final item = _syncedItem(path: tempDir.path, videoFileName: 'missing.mp4');
      expect(item.status, dl.TaskStatus.notFound);
    });
  });

  group('hasVideoFile', () {
    test('true only when a non-empty filename and positive size are both set', () {
      expect(_syncedItem(path: tempDir.path, videoFileName: 'a.mp4', fileSize: 10).hasVideoFile, isTrue);
    });

    test('false when the filename is missing', () {
      expect(_syncedItem(path: tempDir.path, fileSize: 10).hasVideoFile, isFalse);
    });

    test('false when the size is zero or null', () {
      expect(_syncedItem(path: tempDir.path, videoFileName: 'a.mp4', fileSize: 0).hasVideoFile, isFalse);
      expect(_syncedItem(path: tempDir.path, videoFileName: 'a.mp4').hasVideoFile, isFalse);
    });
  });

  group('chapters', () {
    test('joins each chapter image path onto the item directory', () {
      final item = _syncedItem(path: tempDir.path).copyWith(
        fChapters: [
          Chapter(name: 'Ch1', imageUrl: 'chapters/1.jpg', startPosition: Duration.zero),
          Chapter(name: 'Ch2', imageUrl: '2.jpg', startPosition: const Duration(minutes: 5)),
        ],
      );

      final chapters = item.chapters;
      expect(chapters, hasLength(2));
      expect(chapters[0].imageUrl, p.joinAll([tempDir.path, 'chapters/1.jpg']));
      expect(chapters[1].imageUrl, p.joinAll([tempDir.path, '2.jpg']));
    });

    test('empty when there are no chapters', () {
      final item = _syncedItem(path: tempDir.path);
      expect(item.chapters, isEmpty);
    });
  });

  group('images', () {
    test('returns null when fImages is null', () {
      final item = _syncedItem(path: tempDir.path);
      expect(item.images, isNull);
    });

    test('prefixes primary and logo paths with the item directory', () {
      final item = _syncedItem(
        path: tempDir.path,
        fImages: ImagesData(
          primary: ImageData(path: 'primary.jpg'),
          logo: ImageData(path: 'logo.jpg'),
        ),
      );

      expect(item.images?.primary?.path, p.joinAll([tempDir.path, 'primary.jpg']));
      expect(item.images?.logo?.path, p.joinAll([tempDir.path, 'logo.jpg']));
    });

    test('prefixes each backdrop path', () {
      final item = _syncedItem(
        path: tempDir.path,
        fImages: ImagesData(backDrop: [ImageData(path: 'bd1.jpg'), ImageData(path: 'bd2.jpg')]),
      );

      final backDrops = item.images?.backDrop;
      expect(backDrops?.map((e) => e.path).toList(), [
        p.joinAll([tempDir.path, 'bd1.jpg']),
        p.joinAll([tempDir.path, 'bd2.jpg']),
      ]);
    });
  });

  group('trickPlayModel', () {
    test('returns null when fTrickPlayModel is null', () {
      final item = _syncedItem(path: tempDir.path);
      expect(item.trickPlayModel, isNull);
    });

    test('prefixes every trick-play image path with the item directory', () {
      final item = _syncedItem(
        path: tempDir.path,
        fTrickPlayModel: TrickPlayModel(
          width: 100,
          height: 100,
          tileWidth: 4,
          tileHeight: 4,
          thumbnailCount: 16,
          interval: const Duration(seconds: 10),
          images: ['tile0.jpg', 'tile1.jpg'],
        ),
      );

      expect(item.trickPlayModel?.images, [
        p.joinAll([tempDir.path, 'tile0.jpg']),
        p.joinAll([tempDir.path, 'tile1.jpg']),
      ]);
    });
  });

  group('getPlaylistChildIdsAsync', () {
    test('returns empty when overlay.json does not exist', () async {
      final item = _syncedItem(path: tempDir.path);
      expect(await item.getPlaylistChildIdsAsync(), isEmpty);
    });

    test('reads the ids from an existing overlay file', () async {
      File(p.join(tempDir.path, 'overlay.json')).writeAsStringSync(
        jsonEncode({
          'playlistChildIds': ['a', 'b', 'c']
        }),
      );
      final item = _syncedItem(path: tempDir.path);
      expect(await item.getPlaylistChildIdsAsync(), ['a', 'b', 'c']);
    });

    test('returns empty on malformed overlay content instead of throwing', () async {
      File(p.join(tempDir.path, 'overlay.json')).writeAsStringSync('not json');
      final item = _syncedItem(path: tempDir.path);
      expect(await item.getPlaylistChildIdsAsync(), isEmpty);
    });
  });

  group('isTranscoded', () {
    test('false when no overlay file exists', () {
      final item = _syncedItem(path: tempDir.path);
      expect(item.isTranscoded, isFalse);
    });

    test('reflects the overlay flag when present', () {
      File(p.join(tempDir.path, 'overlay.json')).writeAsStringSync(jsonEncode({'isTranscoded': true}));
      final item = _syncedItem(path: tempDir.path);
      expect(item.isTranscoded, isTrue);
    });
  });

  group('data (overlay merge)', () {
    test('returns null when data.json does not exist', () {
      final item = _syncedItem(path: tempDir.path);
      expect(item.data, isNull);
    });

    test('applies overlay container/mediaSources on top of the base dto', () {
      File(p.join(tempDir.path, 'data.json'))
          .writeAsStringSync(jsonEncode(const BaseItemDto(container: 'mkv').toJson()));
      File(p.join(tempDir.path, 'overlay.json')).writeAsStringSync(jsonEncode({'container': 'mp4'}));

      final item = _syncedItem(path: tempDir.path);
      expect(item.data?.container, 'mp4');
    });

    test('falls back to the base value when the overlay omits the field', () {
      File(p.join(tempDir.path, 'data.json'))
          .writeAsStringSync(jsonEncode(const BaseItemDto(container: 'mkv').toJson()));
      File(p.join(tempDir.path, 'overlay.json')).writeAsStringSync(jsonEncode({'isTranscoded': true}));

      final item = _syncedItem(path: tempDir.path);
      expect(item.data?.container, 'mkv');
    });

    test('sets the path to the video file path only when it exists', () {
      File(p.join(tempDir.path, 'data.json')).writeAsStringSync(jsonEncode(const BaseItemDto().toJson()));
      final item = _syncedItem(path: tempDir.path, videoFileName: 'missing.mp4');
      expect(item.data?.path, '');

      File(p.join(tempDir.path, 'missing.mp4')).createSync();
      expect(item.data?.path, item.videoFile.path);
    });
  });

  group('deleteDatFiles', () {
    test('deletes the video file, overlay file, and trick play/chapters directories', () async {
      final item = _syncedItem(path: tempDir.path, videoFileName: 'movie.mp4');
      File(p.join(tempDir.path, 'movie.mp4')).createSync();
      File(p.join(tempDir.path, 'overlay.json')).createSync();
      Directory(p.join(tempDir.path, SyncedItem.trickPlayPath)).createSync();
      Directory(p.join(tempDir.path, SyncedItem.chaptersPath)).createSync();

      final success = await item.deleteDatFiles(_dummyRef());

      expect(success, isTrue);
      expect(item.videoFile.existsSync(), isFalse);
      expect(item.overlayFile.existsSync(), isFalse);
      expect(Directory(p.join(tempDir.path, SyncedItem.trickPlayPath)).existsSync(), isFalse);
      expect(Directory(p.join(tempDir.path, SyncedItem.chaptersPath)).existsSync(), isFalse);
    });

    test('succeeds even when none of the files exist', () async {
      final item = _syncedItem(path: tempDir.path, videoFileName: 'movie.mp4');
      expect(await item.deleteDatFiles(_dummyRef()), isTrue);
    });
  });

  group('getDirSize', () {
    test('sums the sizes of all files under the directory', () async {
      File(p.join(tempDir.path, 'a.bin')).writeAsBytesSync(List.filled(10, 0));
      File(p.join(tempDir.path, 'b.bin')).writeAsBytesSync(List.filled(20, 0));
      final item = _syncedItem(path: tempDir.path);
      expect(await item.getDirSize, 30);
    });

    test('is zero for an empty directory', () async {
      final item = _syncedItem(path: tempDir.path);
      expect(await item.getDirSize, 0);
    });
  });

  group('usage', () {
    test('maps id, fileSize, played and lastPlayed from userData', () {
      final lastPlayed = DateTime(2026, 1, 1);
      final item = _syncedItem(
        path: tempDir.path,
        id: 'item42',
        fileSize: 500,
        userData: UserData(played: true, lastPlayed: lastPlayed),
      );

      final usage = item.usage;
      expect(usage.id, 'item42');
      expect(usage.fileSizeBytes, 500);
      expect(usage.played, isTrue);
      expect(usage.lastPlayed, lastPlayed);
    });

    test('defaults fileSizeBytes to 0 and played to false when unset', () {
      final item = _syncedItem(path: tempDir.path);
      final usage = item.usage;
      expect(usage.fileSizeBytes, 0);
      expect(usage.played, isFalse);
      expect(usage.lastPlayed, isNull);
    });
  });
}
