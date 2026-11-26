import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synthdex/src/characters.dart';
import 'package:synthdex/src/app.dart';
import 'package:synthdex/src/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('released card metadata matches the pinned Global source', () {
    final raw = jsonDecode(
      File('tools/catalog-source/cards.json').readAsStringSync(),
    ) as List;
    final meta = jsonDecode(
      File('tools/catalog-source/provenance.json').readAsStringSync(),
    );
    final stamp = DateTime.parse(meta['as_of']).millisecondsSinceEpoch;
    final released = raw.where((c) => c['releaseAt'] <= stamp).toList();
    expect(gameCharacters.length, 26);
    expect(gameCards.length, released.length);
    expect(gameCards.map((c) => c.id).toSet().length, 1256);
    for (final c in gameCards) {
      final source = released.singleWhere((r) => r['id'] == c.id);
      expect(c.title, source['prefix']);
      expect(c.characterId, source['characterId']);
      expect(c.attribute, source['attr']);
      expect(c.rarity, source['cardRarityType'].replaceFirst('rarity_', ''));
    }
  });
  test(
    'collection persists without changing scores and reset clears it',
    () async {
      final s = AppStore(null);
      await s.save(bundledSongs.first, 3, 2, 1000);
      final before = jsonEncode(s.snapshot()['attempts']);
      await s.setCard(1, owned: true, wishlist: false);
      await s.setCard(2, owned: false, wishlist: true);
      expect(jsonEncode(s.snapshot()['attempts']), before);
      final reopened = AppStore(null);
      await reopened.initialize();
      expect(reopened.collectionEntry(1).owned, true);
      expect(reopened.collectionEntry(2).wishlist, true);
      await expectLater(
        reopened.setCard(-1, owned: true, wishlist: false),
        throwsFormatException,
      );
      expect(reopened.cardCollection.length, 2);
      await reopened.setCard(1, owned: false, wishlist: false);
      expect(reopened.cardCollection.containsKey(1), false);
      await reopened.reset();
      expect(reopened.cardCollection, isEmpty);
      s.dispose();
      reopened.dispose();
    },
  );
  test('older local data opens with an empty collection', () async {
    final original = AppStore(null, memoryOnly: true);
    final data = original.snapshot()..remove('cards');
    SharedPreferences.setMockInitialValues({
      AppStore.localKey: jsonEncode(data),
    });
    final s = AppStore(null);
    await s.initialize();
    expect(s.error, isNull);
    expect(s.cardCollection, isEmpty);
    original.dispose();
    s.dispose();
  });
  testWidgets('roster profile and card ownership work without signing in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = AppStore(null, memoryOnly: true);
    await tester.pumpWidget(SynthDexApp(store: s));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Roster'));
    await tester.pumpAndSettle();
    expect(find.text('Roster & collection'), findsOneWidget);
    await tester.tap(find.text('Ichika Hoshino'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Birthday:'), findsOneWidget);
    final newest = gameCards
        .where((c) => c.characterId == 1)
        .map((c) => c.id)
        .reduce((a, b) => a > b ? a : b);
    final owned = find.byKey(ValueKey('owned-$newest'));
    await tester.ensureVisible(owned);
    await tester.pumpAndSettle();
    await tester.tap(owned);
    await tester.pumpAndSettle();
    expect(s.collectionEntry(newest).owned, true);
    expect(s.attempts, isEmpty);
    expect(s.signedIn, false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
}
