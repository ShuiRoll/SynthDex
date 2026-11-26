import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synthdex/src/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'guest records, favorites and preferences persist after reopening',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final first = AppStore(null, storage: prefs);
      await first.initialize();
      expect(first.signedIn, isFalse);
      await first.save(bundledSongs.first, 3, 2, 1050000);
      await first.favorite(bundledSongs.first);
      await first.preferences('Player', 4, appTheme: 'amoled');
      final second = AppStore(null, storage: prefs);
      await second.initialize();
      expect(second.attempts.single.score, 1050000);
      expect(second.favorites, contains('tell-your-world'));
      expect(second.name, 'Player');
      expect(second.defaultDifficulty, 4);
      expect(second.theme, 'amoled');
      expect(second.signedIn, isFalse);
      first.dispose();
      second.dispose();
    },
  );

  test('edit, clear and delete preserve the intended history', () async {
    final store = AppStore(null, memoryOnly: true);
    await store.save(bundledSongs.first, 3, 1, 500);
    final id = store.attempts.single.id;
    await store.save(bundledSongs.first, 3, 2, 1000, attemptId: id);
    expect(store.attempts, hasLength(1));
    expect(store.best('tell-your-world', 3), 1000);
    await store.clear(bundledSongs.first, 3);
    expect(store.best('tell-your-world', 3), null);
    expect(store.history('tell-your-world', 3), hasLength(1));
    await store.save(bundledSongs.first, 3, 1, 600);
    expect(store.best('tell-your-world', 3), 600);
    await store.deleteAttempt(id);
    expect(store.attempts, hasLength(1));
    store.dispose();
  });

  test(
    'derived progress follows edits, archives, deletes and replaced lists',
    () async {
      final store = AppStore(null, memoryOnly: true);
      final song = bundledSongs.first;
      await store.save(song, 3, 2, 1200);
      await store.save(song, 3, 1, 900);
      expect(store.status(song.id, 3), 2);
      expect(store.best(song.id, 3), 1200);
      final older = store.history(song.id, 3).last.id;
      await store.save(song, 3, 3, 1500, attemptId: older);
      expect(store.status(song.id, 3), 3);
      expect(store.best(song.id, 3), 1500);
      await store.clear(song, 3);
      expect(store.status(song.id, 3), -1);
      expect(store.best(song.id, 3), null);
      await store.save(song, 3, 1, null);
      expect(store.status(song.id, 3), 1);
      expect(store.best(song.id, 3), null);
      await store.deleteAttempt(store.attempts.lastWhere((a) => a.active).id);
      expect(store.status(song.id, 3), -1);
      store.attempts = [
        Attempt('a', song.id, 3, 3, 999, DateTime.utc(2026), true),
        Attempt('b', song.id, 3, 1, 5000, DateTime.utc(2026), false),
      ];
      expect(store.status(song.id, 3), 3);
      expect(store.best(song.id, 3), 999);
      expect(store.count(3), 1);
      expect(
        () => store.attempts.add(store.attempts.first),
        throwsUnsupportedError,
      );
      expect(() => store.attempts.clear(), throwsUnsupportedError);
      store.attempts = [];
      expect(store.status(song.id, 3), -1);
      expect(store.best(song.id, 3), null);
      store.dispose();
    },
  );

  test('invalid input never replaces persisted data', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(null, storage: prefs);
    await store.save(bundledSongs.first, 3, 2, 1000);
    final before = prefs.getString(AppStore.localKey);
    await expectLater(
      store.save(bundledSongs.first, 3, 2, -1),
      throwsFormatException,
    );
    await expectLater(store.preferences('x' * 81, 3), throwsFormatException);
    await expectLater(
      store.save(bundledSongs.first, 7, 2, 100),
      throwsFormatException,
    );
    expect(prefs.getString(AppStore.localKey), before);
    expect(store.attempts, hasLength(1));
    store.dispose();
  });

  test(
    'concurrent local changes are serialized without losing records',
    () async {
      final store = AppStore(null, memoryOnly: true);
      await Future.wait(
        List.generate(10, (i) => store.save(bundledSongs.first, 3, 1, i)),
      );
      expect(store.attempts, hasLength(10));
      expect(store.attempts.map((a) => a.id).toSet(), hasLength(10));
      store.dispose();
    },
  );

  test('reset clears personal data but keeps the catalog', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(null, storage: prefs);
    await store.save(bundledSongs.first, 3, 2, 100);
    await store.favorite(bundledSongs.first);
    await store.preferences('Name', 4, appTheme: 'amoled');
    final changesBeforeReset = store.pendingChanges;
    await store.reset();
    final reopened = AppStore(null, storage: prefs);
    await reopened.initialize();
    expect(reopened.attempts, isEmpty);
    expect(reopened.favorites, isEmpty);
    expect(reopened.name, isEmpty);
    expect(reopened.theme, 'dark');
    expect(reopened.pendingChanges, changesBeforeReset + 1);
    expect(
      reopened.songs,
      hasLength(bundledSongs.where((s) => s.available).length),
    );
    store.dispose();
    reopened.dispose();
  });

  test('unreadable data is preserved until an explicit reset', () async {
    SharedPreferences.setMockInitialValues({
      AppStore.localKey: 'not valid json',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(null, storage: prefs);
    await store.initialize();
    expect(store.error, isNotNull);
    await expectLater(store.favorite(bundledSongs.first), throwsStateError);
    expect(prefs.getString(AppStore.localKey), 'not valid json');
    await store.reset();
    expect(
      jsonDecode(prefs.getString(AppStore.localKey)!)['attempts'],
      isEmpty,
    );
    store.dispose();
  });

  test('only cloud operations require an account', () async {
    final store = AppStore(null, memoryOnly: true);
    await store.favorite(bundledSongs.first);
    await store.save(bundledSongs.first, 3, 1, null);
    await expectLater(store.saveBackup(), throwsStateError);
    await expectLater(store.restoreBackup(), throwsStateError);
    expect(store.attempts, hasLength(1));
    expect(store.favorites, hasLength(1));
    store.dispose();
  });
}
