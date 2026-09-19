import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/models/syncing/smart_download_policy.dart';

void main() {
  group('SmartDownloadPolicy', () {
    test('no budget means no reclaim regardless of usage', () {
      const policy = SmartDownloadPolicy();
      final result = policy.evaluate([
        const SyncedItemUsage(id: 'a', fileSizeBytes: 1000000000, played: true),
      ]);

      expect(result.reclaimItemIds, isEmpty);
      expect(result.bytesUsed, 1000000000);
      expect(result.bytesFreed, 0);
    });

    test('usage under budget means no reclaim', () {
      const policy = SmartDownloadPolicy(storageBudgetBytes: 1000);
      final result = policy.evaluate([
        const SyncedItemUsage(id: 'a', fileSizeBytes: 500, played: true),
      ]);

      expect(result.reclaimItemIds, isEmpty);
      expect(result.bytesUsedAfterReclaim, 500);
    });

    test('usage exactly at budget means no reclaim', () {
      const policy = SmartDownloadPolicy(storageBudgetBytes: 500);
      final result = policy.evaluate([
        const SyncedItemUsage(id: 'a', fileSizeBytes: 500, played: true),
      ]);

      expect(result.reclaimItemIds, isEmpty);
      expect(result.bytesUsedAfterReclaim, 500);
    });

    test('zero budget reclaims all watched items', () {
      const policy = SmartDownloadPolicy(storageBudgetBytes: 0);
      final result = policy.evaluate([
        SyncedItemUsage(id: 'oldest', fileSizeBytes: 300, played: true, lastPlayed: DateTime(2026, 1, 1)),
        SyncedItemUsage(id: 'newer', fileSizeBytes: 300, played: true, lastPlayed: DateTime(2026, 2, 1)),
      ]);

      expect(result.reclaimItemIds, ['oldest', 'newer']);
      expect(result.bytesUsedAfterReclaim, 0);
    });

    test('reclaims oldest watched item first (LRU) until back under budget', () {
      const policy = SmartDownloadPolicy(storageBudgetBytes: 700);
      final result = policy.evaluate([
        SyncedItemUsage(id: 'newest', fileSizeBytes: 400, played: true, lastPlayed: DateTime(2026, 3, 1)),
        SyncedItemUsage(id: 'oldest', fileSizeBytes: 400, played: true, lastPlayed: DateTime(2026, 1, 1)),
        SyncedItemUsage(id: 'middle', fileSizeBytes: 400, played: true, lastPlayed: DateTime(2026, 2, 1)),
      ]);

      expect(result.bytesUsed, 1200);
      expect(result.reclaimItemIds, ['oldest', 'middle']);
      expect(result.bytesFreed, 800);
      expect(result.bytesUsedAfterReclaim, 400);
      expect(result.bytesUsedAfterReclaim <= 700, isTrue);
    });

    test('never reclaims unwatched items even when budget stays exceeded', () {
      const policy = SmartDownloadPolicy(storageBudgetBytes: 100);
      final result = policy.evaluate([
        const SyncedItemUsage(id: 'unwatched', fileSizeBytes: 900, played: false),
      ]);

      expect(result.reclaimItemIds, isEmpty);
      expect(result.bytesUsedAfterReclaim, 900);
    });

    test('items with no lastPlayed are reclaimed after items with known playback history', () {
      const policy = SmartDownloadPolicy(storageBudgetBytes: 400);
      final result = policy.evaluate([
        SyncedItemUsage(id: 'known', fileSizeBytes: 300, played: true, lastPlayed: DateTime(2026, 1, 1)),
        const SyncedItemUsage(id: 'unknown', fileSizeBytes: 300, played: true),
      ]);

      expect(result.reclaimItemIds, ['known']);
      expect(result.bytesUsedAfterReclaim, 300);
    });

    test('uses IDs to deterministically order equally old items', () {
      const policy = SmartDownloadPolicy(storageBudgetBytes: 300);
      final result = policy.evaluate([
        SyncedItemUsage(id: 'b', fileSizeBytes: 300, played: true, lastPlayed: DateTime(2026, 1, 1)),
        SyncedItemUsage(id: 'a', fileSizeBytes: 300, played: true, lastPlayed: DateTime(2026, 1, 1)),
      ]);

      expect(result.reclaimItemIds, ['a']);
    });

    test('rejects negative file sizes and storage budgets', () {
      expect(
        () => SyncedItemUsage(id: 'bad-size', fileSizeBytes: -1, played: false),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => SmartDownloadPolicy(storageBudgetBytes: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('stops reclaiming as soon as usage is back within budget', () {
      const policy = SmartDownloadPolicy(storageBudgetBytes: 500);
      final result = policy.evaluate([
        SyncedItemUsage(id: 'oldest', fileSizeBytes: 300, played: true, lastPlayed: DateTime(2026, 1, 1)),
        SyncedItemUsage(id: 'newer', fileSizeBytes: 300, played: true, lastPlayed: DateTime(2026, 2, 1)),
      ]);

      expect(result.reclaimItemIds, ['oldest']);
      expect(result.bytesUsedAfterReclaim, 300);
    });

    test('uses IDs to order two items that both have no lastPlayed', () {
      const policy = SmartDownloadPolicy(storageBudgetBytes: 300);
      final result = policy.evaluate([
        const SyncedItemUsage(id: 'b', fileSizeBytes: 300, played: true),
        const SyncedItemUsage(id: 'a', fileSizeBytes: 300, played: true),
      ]);

      expect(result.reclaimItemIds, ['a']);
    });
  });
}
