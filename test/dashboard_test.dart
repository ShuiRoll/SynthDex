import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:synthdex/src/store.dart';

class LoopbackHttpOverrides extends HttpOverrides {}

class SignedInStore extends AppStore {
  SignedInStore(super.client, {required super.storage});
  @override
  String get userId => 'user';
  @override
  String? get cloudUserId => 'user';
}

void main() {
  test('profile totals deduplicate songs and exclude archived and wishlist-only data', () async {
    final store = AppStore(null, memoryOnly: true);
    final song = store.songs.first;
    await store.save(song, 3, 1, null);
    await store.save(song, 3, 2, 2000);
    await store.save(song, 4, 3, 3000);
    expect(store.completedSongCount, 1);
    await store.clear(song, 3);
    expect(store.completedSongCount, 1);
    await store.clear(song, 4);
    expect(store.completedSongCount, 0);
    await store.setCard(1, owned: true, wishlist: true);
    await store.setCard(2, owned: false, wishlist: true);
    expect(store.collectedCardCount, 1);
    await store.setCard(1, owned: false, wishlist: true);
    expect(store.collectedCardCount, 0);
    store.dispose();
  });
  test('next-to-play uses selected difficulty and favorites without inventing progress', () async {
    final store = AppStore(null, memoryOnly: true);
    final favorite = store.songs.lastWhere((s) => s.hasChart(3));
    await store.favorite(favorite);
    expect(store.nextSongs.first.id, favorite.id);
    expect(store.nextSongs.length, 3);
    expect(store.attempts, isEmpty);
    await store.save(favorite, 3, 1, null);
    expect(store.nextSongs.any((s) => s.id == favorite.id), false);
    await store.updateAppSettings(5, 'dark');
    expect(store.nextSongs.every((s) => s.hasChart(5)), true);
    store.dispose();
  });
  test('latest activity is chronological rather than insertion order', () {
    final store = AppStore(null, memoryOnly: true);
    store.attempts = [
      Attempt('a', 'tell-your-world', 3, 2, 200, DateTime(2026, 1), true),
      Attempt('b', 'tell-your-world', 3, 1, 100, DateTime(2026, 3), true),
      Attempt('c', 'tell-your-world', 3, 0, null, DateTime(2026, 2), false),
    ];
    expect(store.recentAttempts.map((a) => a.id), ['b', 'c', 'a']);
    store.dispose();
  });

  test(
    'backup timestamp and pending changes persist, clear and survive reset',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var savedCount = 0;
      const stamp = '2026-05-01T12:00:00.000Z';
      final subscription = server.listen((request) async {
        final path = request.uri.path;
        request.response.headers.contentType = ContentType.json;
        if (path.endsWith('save_backup_v3')) {
          savedCount++;
          request.response.write(jsonEncode(stamp));
        } else if (path.endsWith('load_backup_v3')) {
          request.response.write(
            jsonEncode({
              'version': 1,
              'saved_at': '2026-06-02T08:30:00.000Z',
              'attempts': <dynamic>[],
              'favorites': <String>[],
              'cards': <dynamic>[],
              'name': 'Restored',
              'difficulty': 3,
              'theme': 'dark',
              'appearance': 'system',
            }),
          );
        } else {
          request.response.write('{}');
        }
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-key',
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SignedInStore(client, storage: prefs);
      await store.initialize();
      final song = bundledSongs.first;
      await store.save(song, 3, 1, 100);
      await store.setCard(1, owned: true, wishlist: false);
      expect(store.pendingChanges, 2);
      expect(store.backupAt, isNull);
      await store.saveBackup();
      expect(savedCount, 1);
      expect(store.pendingChanges, 0);
      expect(store.backupAt, DateTime.utc(2026, 5, 1, 12));
      await store.favorite(song);
      expect(store.pendingChanges, 1);
      final reopened = SignedInStore(client, storage: prefs);
      await reopened.initialize();
      expect(reopened.pendingChanges, 1);
      expect(reopened.backupAt, DateTime.utc(2026, 5, 1, 12));
      await reopened.restoreBackup();
      expect(reopened.pendingChanges, 0);
      expect(reopened.backupAt, DateTime.utc(2026, 6, 2, 8, 30));
      expect(reopened.name, 'Restored');
      expect(prefs.getString(AppStore.beforeReplaceKey), isNotNull);
      expect(reopened.undoableReplacement, ReplacementKind.restore);
      await reopened.reset();
      expect(reopened.pendingChanges, 1);
      expect(reopened.attempts, isEmpty);
      store.dispose();
      reopened.dispose();
      await client.dispose();
      await subscription.cancel();
      await server.close(force: true);
    }, LoopbackHttpOverrides()),
  );
}
