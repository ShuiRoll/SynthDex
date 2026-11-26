import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:synthdex/src/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final first = bundledSongs.first;
  final second = bundledSongs.firstWhere(
    (song) => song.id != first.id && song.available && song.hasChart(3),
  );

  Future<String> exportWithProgress(AppStore store) async {
    await store.save(first, 3, 2, 1000);
    await store.clear(first, 3);
    await store.favorite(first);
    await store.setCard(
      store.cardCatalog.first.id,
      owned: true,
      wishlist: false,
    );
    return store.progressExportJson();
  }

  Map<String, dynamic> copyOf(String contents) =>
      jsonDecode(contents) as Map<String, dynamic>;

  test('replace restores progress but keeps device preferences', () async {
    final source = AppStore(null, memoryOnly: true);
    final exported = await exportWithProgress(source);
    final cardId = source.cardCatalog.first.id;

    final target = AppStore(null, memoryOnly: true);
    await target.save(second, 3, 1, 400);
    await target.favorite(second);
    await target.setCard(
      target.cardCatalog.last.id,
      owned: false,
      wishlist: true,
    );
    await target.preferences('Keeper', 4, appTheme: 'amoled');

    final file = await target.readProgressFile(exported);
    expect(file.attemptCount, 1);
    expect(file.favoriteCount, 1);
    expect(file.cardCount, 1);
    await file.apply(merge: false);

    expect(target.attempts.map((a) => a.songId), [first.id]);
    expect(target.attempts.single.active, isFalse);
    expect(target.favorites, {first.id});
    expect(target.cardCollection.keys, [cardId]);
    expect(target.collectionEntry(cardId).owned, isTrue);
    expect(target.name, 'Keeper');
    expect(target.defaultDifficulty, 4);
    expect(target.theme, 'amoled');
    source.dispose();
    target.dispose();
  });

  test(
    'merge unions attempts, favorites and card flags idempotently',
    () async {
      final source = AppStore(null, memoryOnly: true);
      final cardId = source.cardCatalog.first.id;
      await source.save(first, 3, 2, 1000);
      await source.favorite(first);
      await source.setCard(cardId, owned: true, wishlist: false);
      final exported = await source.progressExportJson();

      final target = AppStore(null, memoryOnly: true);
      await target.save(second, 3, 1, 400);
      await target.favorite(second);
      await target.setCard(cardId, owned: false, wishlist: true);
      final localOnlyCard = target.cardCatalog.last.id;
      await target.setCard(localOnlyCard, owned: true, wishlist: false);

      final file = await target.readProgressFile(exported);
      await file.apply(merge: true);
      expect(target.attempts, hasLength(2));
      expect(target.favorites, {first.id, second.id});
      expect(target.collectionEntry(cardId).owned, isTrue);
      expect(target.collectionEntry(cardId).wishlist, isTrue);
      expect(target.collectionEntry(localOnlyCard).owned, isTrue);
      expect(target.status(first.id, 3), 2);

      final again = await target.readProgressFile(exported);
      await again.apply(merge: true);
      expect(target.attempts, hasLength(2));
      expect(target.favorites, hasLength(2));
      source.dispose();
      target.dispose();
    },
  );

  test('invalid files are rejected without changing local data', () async {
    final source = AppStore(null, memoryOnly: true);
    final exported = await exportWithProgress(source);
    final base = copyOf(exported);

    Map<String, dynamic> variant(void Function(Map<String, dynamic>) edit) {
      final copy = copyOf(jsonEncode(base));
      edit(copy);
      return copy;
    }

    final unknownSong = variant((copy) {
      (copy['attempts'] as List).first['song_id'] = 'not-a-song';
    });
    final duplicateAttempt = variant((copy) {
      final attempts = copy['attempts'] as List;
      attempts.add(Map<String, dynamic>.from(attempts.first as Map));
    });
    final unknownCard = variant((copy) {
      (copy['cards'] as List).first['card_id'] = -1;
    });
    final emptyCard = variant((copy) {
      (copy['cards'] as List).first['owned'] = false;
      (copy['cards'] as List).first['wishlist'] = false;
    });
    final unknownFavorite = variant((copy) {
      copy['favorites'] = ['not-a-song'];
    });
    final wrongVersion = variant((copy) => copy['version'] = 2);
    final wrongFormat = variant((copy) => copy['format'] = 'other');
    final noPin = variant((copy) => copy['catalog'] = 'nope');
    final noAttempts = variant((copy) => copy.remove('attempts'));
    final badAttemptType = variant((copy) {
      (copy['attempts'] as List).first['difficulty'] = 'Expert';
    });
    final badCardType = variant((copy) {
      (copy['cards'] as List).first['owned'] = 'yes';
    });
    final badFavoriteType = variant((copy) => copy['favorites'] = [7]);

    final target = AppStore(null, memoryOnly: true);
    await target.save(second, 3, 1, 400);
    final incoming = [
      'not json',
      '[]',
      '{}',
      jsonEncode(wrongFormat),
      jsonEncode(wrongVersion),
      jsonEncode(noPin),
      jsonEncode(noAttempts),
      jsonEncode(badAttemptType),
      jsonEncode(badCardType),
      jsonEncode(badFavoriteType),
      jsonEncode(unknownSong),
      jsonEncode(duplicateAttempt),
      jsonEncode(unknownCard),
      jsonEncode(emptyCard),
      jsonEncode(unknownFavorite),
    ];
    for (final contents in incoming) {
      await expectLater(
        target.readProgressFile(contents),
        throwsFormatException,
        reason: contents,
      );
    }
    expect(target.attempts.single.songId, second.id);
    expect(target.favorites, isEmpty);
    source.dispose();
    target.dispose();
  });

  test('files pinned to another catalog are rejected', () async {
    final source = AppStore(null, memoryOnly: true);
    final exported = await exportWithProgress(source);

    final otherCommit = copyOf(exported);
    (otherCommit['catalog'] as Map)['commit'] = 'deadbeefdeadbeef';
    final otherSource = copyOf(exported);
    (otherSource['catalog'] as Map)['source'] = 'someone/else';

    final target = AppStore(null, memoryOnly: true);
    await target.save(second, 3, 1, 400);
    for (final mismatch in [otherCommit, otherSource]) {
      await expectLater(
        target.readProgressFile(jsonEncode(mismatch)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('different song catalog'),
          ),
        ),
      );
    }
    expect(target.attempts.single.songId, second.id);
    expect(target.favorites, isEmpty);
    source.dispose();
    target.dispose();
  });
}
