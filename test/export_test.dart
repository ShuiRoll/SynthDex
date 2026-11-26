import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synthdex/src/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'progress export is versioned, pinned and mirrors the local progress',
    () async {
      final provenance =
          jsonDecode(
                File('tools/catalog-source/provenance.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final store = AppStore(null, memoryOnly: true);
      final song = bundledSongs.firstWhere(
        (s) => s.available && s.hasChart(3),
      );
      await store.save(song, 3, 2, 1234);
      await store.clear(song, 3);
      await store.favorite(song);
      await store.setCard(1, owned: true, wishlist: false);
      final root =
          jsonDecode(await store.progressExportJson()) as Map<String, dynamic>;
      expect(root['format'], 'synthdex.progress');
      expect(root['version'], 1);
      expect(DateTime.tryParse(root['exported_at'] as String), isNotNull);
      // No device preferences or cloud bookkeeping in a progress file.
      expect(
        root.keys,
        unorderedEquals([
          'format',
          'version',
          'exported_at',
          'catalog',
          'attempts',
          'favorites',
          'cards',
        ]),
      );
      final catalog = root['catalog'] as Map<String, dynamic>;
      expect(catalog.keys, unorderedEquals(['source', 'commit', 'as_of']));
      expect(catalog['source'], provenance['repository']);
      expect(catalog['commit'], provenance['commit']);
      expect(catalog['as_of'], provenance['as_of']);
      final local = store.snapshot();
      expect(root['attempts'], local['attempts']);
      expect(root['favorites'], local['favorites']);
      expect(root['cards'], local['cards']);
      final attempts = root['attempts'] as List;
      expect(attempts, hasLength(1));
      expect(attempts.single['active'], false);
      expect(attempts.single['score'], 1234);
      store.dispose();
    },
  );
  test('export refuses unreadable local data', () async {
    SharedPreferences.setMockInitialValues({
      AppStore.localKey: '{"version":1}',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(null, storage: prefs);
    await store.initialize();
    expect(store.error, isNotNull);
    await expectLater(store.progressExportJson(), throwsStateError);
    store.dispose();
  });
}
