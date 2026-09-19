import 'package:driftfin/models/library_search/library_search_model.dart';
import 'package:driftfin/models/playback/playback_queue_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('supportsRefill', () {
    test('artist, album/playlist derived sources support refill', () {
      expect(const ArtistLatestTracksQueueSource(artistId: 'a', limit: 10).supportsRefill, isTrue);
      expect(const ArtistCatalogQueueSource(artistId: 'a', limit: 10).supportsRefill, isTrue);
      expect(const PlaylistAudioQueueSource(playlistId: 'p', shuffle: false, limit: 10).supportsRefill, isTrue);
      expect(
        const LibraryMusicQueueSource(
          libraryState: LibrarySearchModel(),
          parentId: [null],
          recursive: null,
          shuffle: false,
          limit: 10,
        ).supportsRefill,
        isTrue,
      );
    });

    test('instant mix sources do not support refill (they are a fixed one-shot list)', () {
      expect(const AlbumInstantMixQueueSource(albumId: 'a', limit: 10).supportsRefill, isFalse);
      expect(const ArtistInstantMixQueueSource(artistId: 'a', limit: 10).supportsRefill, isFalse);
      expect(const AudioInstantMixQueueSource(audioId: 'a', limit: 10).supportsRefill, isFalse);
    });
  });

  group('limit', () {
    test('is stored as provided on the base class', () {
      expect(const ArtistCatalogQueueSource(artistId: 'a', limit: 42).limit, 42);
      expect(const PlaylistAudioQueueSource(playlistId: 'p', shuffle: false, limit: 7).limit, 7);
    });
  });
}
