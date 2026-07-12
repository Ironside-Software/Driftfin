import 'package:driftfin/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:driftfin/models/collection_types.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/library_filter_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CollectionTypeExtension.videos', () {
    test('true for movies/tvshows/folders/homevideos', () {
      expect(CollectionType.movies.videos, isTrue);
      expect(CollectionType.tvshows.videos, isTrue);
      expect(CollectionType.folders.videos, isTrue);
      expect(CollectionType.homevideos.videos, isTrue);
    });

    test('false for everything else, including null', () {
      expect(CollectionType.music.videos, isFalse);
      expect(CollectionType.books.videos, isFalse);
      expect(null.videos, isFalse);
    });
  });

  group('CollectionTypeExtension.supportsExtras / hasSubtitles', () {
    test('true only for movies and tvshows', () {
      for (final type in [CollectionType.movies, CollectionType.tvshows]) {
        expect(type.supportsExtras, isTrue);
        expect(type.hasSubtitles, isTrue);
      }
    });

    test('false for other types and null', () {
      expect(CollectionType.music.supportsExtras, isFalse);
      expect(CollectionType.music.hasSubtitles, isFalse);
      expect(null.supportsExtras, isFalse);
      expect(null.hasSubtitles, isFalse);
    });
  });

  group('CollectionTypeExtension.audio', () {
    test('true only for music', () {
      expect(CollectionType.music.audio, isTrue);
      expect(CollectionType.movies.audio, isFalse);
      expect(null.audio, isFalse);
    });
  });

  group('CollectionTypeExtension.photos', () {
    test('true for homevideos and photos', () {
      expect(CollectionType.homevideos.photos, isTrue);
      expect(CollectionType.photos.photos, isTrue);
    });

    test('false otherwise', () {
      expect(CollectionType.movies.photos, isFalse);
      expect(null.photos, isFalse);
    });
  });

  group('CollectionTypeExtension.itemKinds', () {
    test('maps each collection type to its expected item kinds', () {
      expect(CollectionType.music.itemKinds, {FladderItemType.musicAlbum});
      expect(CollectionType.movies.itemKinds, {FladderItemType.movie});
      expect(CollectionType.tvshows.itemKinds, {FladderItemType.series});
      expect(CollectionType.homevideos.itemKinds, {
        FladderItemType.photoAlbum,
        FladderItemType.folder,
        FladderItemType.photo,
        FladderItemType.video,
      });
      expect(CollectionType.livetv.itemKinds, {FladderItemType.tvchannel});
    });

    test('unmapped types (and null) return an empty set', () {
      expect(CollectionType.boxsets.itemKinds, isEmpty);
      expect(CollectionType.books.itemKinds, isEmpty);
      expect(CollectionType.playlists.itemKinds, isEmpty);
      expect(CollectionType.folders.itemKinds, isEmpty);
      expect(null.itemKinds, isEmpty);
    });
  });

  group('CollectionTypeExtension.defaultFilters', () {
    test('homevideos/photos default to non-recursive', () {
      expect(CollectionType.homevideos.defaultFilters.recursive, isFalse);
      expect(CollectionType.photos.defaultFilters.recursive, isFalse);
    });

    test('everything else (including null) defaults to recursive', () {
      expect(CollectionType.movies.defaultFilters.recursive, isTrue);
      expect(CollectionType.tvshows.defaultFilters.recursive, isTrue);
      expect(null.defaultFilters.recursive, isTrue);
      expect(null.defaultFilters, const LibraryFilterModel(recursive: true));
    });
  });

  group('CollectionTypeExtension.aspectRatio', () {
    test('0.8 for music/homevideos/boxsets/photos/livetv/playlists', () {
      for (final type in [
        CollectionType.music,
        CollectionType.homevideos,
        CollectionType.boxsets,
        CollectionType.photos,
        CollectionType.livetv,
        CollectionType.playlists,
      ]) {
        expect(type.aspectRatio, 0.8);
      }
    });

    test('1.3 for folders', () {
      expect(CollectionType.folders.aspectRatio, 1.3);
    });

    test('null for movies/tvshows/books and the null type itself', () {
      expect(CollectionType.movies.aspectRatio, isNull);
      expect(CollectionType.tvshows.aspectRatio, isNull);
      expect(CollectionType.books.aspectRatio, isNull);
      expect(null.aspectRatio, isNull);
    });
  });
}
