import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:synthdex/src/characters.dart';
import 'package:synthdex/src/store.dart';

class LoopbackHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('every bundled title and chart level matches the pinned EN source', () {
    final music = jsonDecode(
      File('tools/catalog-source/musics.json').readAsStringSync(),
    ) as List;
    final charts = jsonDecode(
      File('tools/catalog-source/musicDifficulties.json').readAsStringSync(),
    ) as List;
    const legacy = {
      1: 'tell-your-world',
      126: 'cinema',
      138: 'king',
      248: 'bug',
    };
    expect(bundledSongs.length, music.length);
    expect(bundledSongs.map((s) => s.id).toSet().length, music.length);
    for (final row in music) {
      final id = legacy[row['id']] ?? 'sekai-${row['id']}';
      final song = bundledSongs.singleWhere((s) => s.id == id);
      expect(song.title, row['title'], reason: id);
      final expected = List<int>.filled(6, 0);
      for (final chart in charts.where((c) => c['musicId'] == row['id'])) {
        expected[difficulties.indexWhere(
              (d) => d.toLowerCase() == chart['musicDifficulty'],
            )] =
            chart['playLevel'];
      }
      expect(song.levels, expected, reason: id);
    }
    final store = AppStore(null, memoryOnly: true);
    expect(store.songs.length, 647);
    expect(store.chartCount(), 3356);
    expect(store.chartCount(5), 121);
    for (final id in [
      'sekai-241',
      'sekai-290',
      'sekai-388',
      'sekai-600',
      'sekai-674',
      'sekai-675',
      'sekai-676',
    ]) {
      expect(store.songById(id).available, isFalse);
    }
    expect(
      store.songById('sekai-139').unitNames,
      containsAll(['Leo/need', 'MORE MORE JUMP!', 'Vivid BAD SQUAD']),
    );
    store.dispose();
  });

  test(
    'legacy sample cache cannot replace full catalog or lose personal progress',
    () async {
      SharedPreferences.setMockInitialValues({
        'synthdex.catalog.v1': jsonEncode([bundledSongs.first.toJson()]),
        AppStore.localKey: jsonEncode({
          'version': 1,
          'name': 'Player',
          'difficulty': 3,
          'theme': 'dark',
          'favorites': ['bug'],
          'attempts': [
            Attempt(
              '00000000-0000-4000-8000-000000000001',
              'bug',
              3,
              2,
              1000,
              DateTime.utc(2026),
              true,
            ).toJson(),
          ],
        }),
      });
      final store = AppStore(null);
      await store.initialize();
      expect(store.songs.length, 647);
      expect(store.favorites, contains('bug'));
      expect(store.best('bug', 3), 1000);
      expect(store.error, isNull);
      store.dispose();
    },
  );

  test('APPEND persists and nonexistent charts cannot be recorded', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(null);
    final append = bundledSongs.firstWhere((s) => s.available && s.hasChart(5));
    await store.save(append, 5, 2, 12345);
    await store.preferences('Player', 5);
    final reopened = AppStore(null);
    await reopened.initialize();
    expect(reopened.best(append.id, 5), 12345);
    expect(reopened.defaultDifficulty, 5);
    expect(reopened.count(1, 5), 1);
    final withoutAppend = bundledSongs.firstWhere(
      (s) => s.available && !s.hasChart(5),
    );
    await expectLater(
      reopened.save(withoutAppend, 5, 1, null),
      throwsFormatException,
    );
    store.dispose();
    reopened.dispose();
  });

  test(
    'refresh loads every page and failed refresh preserves complete catalog',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var fail = false;
      final songOffsets = <int>[], cardOffsets = <int>[];
      final subscription = server.listen((request) async {
        final isCards = request.uri.path.endsWith('character_cards');
        final offset = int.parse(request.uri.queryParameters['offset'] ?? '0');
        (isCards ? cardOffsets : songOffsets).add(offset);
        request.response.headers.contentType = ContentType.json;
        if (!isCards && fail && offset == 100) {
          request.response.statusCode = 500;
          request.response.write('{"message":"temporary failure"}');
        } else if (isCards) {
          request.response.write(
            jsonEncode([
              for (var i = offset; i < offset + 100 && i < 2; i++)
                {
                  'id': 9000 + i,
                  'character_id': 1,
                  'title': 'Remote card $i',
                  'rarity_id': '4',
                  'attribute_id': 'cool',
                  'asset_bundle': 'remote_$i',
                },
            ]),
          );
        } else {
          request.response.write(
            jsonEncode([
              for (var i = offset; i < offset + 100 && i < 205; i++)
                {
                  'id': 'test-$i',
                  'title': 'Song $i',
                  'color': 0xff6f50b9,
                  'available': true,
                  'search_alias': '',
                  'artists': {'name': 'Artist'},
                  'song_units': [
                    {
                      'units': {'name': 'Leo/need'},
                    },
                  ],
                  'charts': [
                    {'difficulty': 3, 'level': 25},
                  ],
                },
            ]),
          );
        }
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-key',
      );
      final store = AppStore(client, memoryOnly: true);
      await store.refresh();
      expect(songOffsets, [0, 100, 200]);
      expect(cardOffsets, [0]);
      expect(store.songs.length, 205);
      expect(store.cardCatalog.length, gameCards.length + 2);
      expect(store.cardCatalog.first.title, 'Remote card 0');
      expect(store.cardCatalog.first.assetBundle, 'remote_0');
      expect(store.songs.last.id, 'test-204');
      fail = true;
      await store.refresh();
      expect(store.songs.length, 205);
      expect(store.cardCatalog.length, gameCards.length + 2);
      expect(store.error, isNotNull);
      store.dispose();
      await client.dispose();
      await subscription.cancel();
      await server.close(force: true);
    }, LoopbackHttpOverrides()),
  );

  test(
    'catalog refresh respects the freshness window unless forced',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requests = 0;
      final subscription = server.listen((request) async {
        requests++;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            request.uri.path.endsWith('character_cards')
                ? [
                    {
                      'id': 9000,
                      'character_id': 1,
                      'title': 'Remote card',
                      'rarity_id': '4',
                      'attribute_id': 'cool',
                      'asset_bundle': 'remote_bundle',
                    },
                  ]
                : [
                    {
                      'id': 'test-0',
                      'title': 'Song',
                      'color': 0xff6f50b9,
                      'available': true,
                      'search_alias': '',
                      'artists': {'name': 'Artist'},
                      'song_units': [
                        {
                          'units': {'name': 'Leo/need'},
                        },
                      ],
                      'charts': [
                        {'difficulty': 3, 'level': 25},
                      ],
                    },
                  ],
          ),
        );
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-key',
      );
      SharedPreferences.setMockInitialValues({
        AppStore.catalogRefreshedKey: DateTime.now().toUtc().toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore(client, storage: prefs);
      await store.initialize();
      await store.refresh();
      expect(requests, 0);
      await store.refresh(force: true);
      expect(requests, 2);
      await store.refresh();
      expect(requests, 2);
      store.dispose();
      await client.dispose();
      await subscription.cancel();
      await server.close(force: true);
    }, LoopbackHttpOverrides()),
  );

  test(
    'card roster is cached and keeps cards dropped upstream',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var dropFirst = false;
      final subscription = server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            request.uri.path.endsWith('character_cards')
                ? [
                    if (!dropFirst)
                      {
                        'id': 9001,
                        'character_id': 1,
                        'title': 'Kept card',
                        'rarity_id': '3',
                        'attribute_id': 'cool',
                        'asset_bundle': 'kept_bundle',
                      },
                    {
                      'id': 9002,
                      'character_id': 1,
                      'title': 'Newest card',
                      'rarity_id': '4',
                      'attribute_id': 'cute',
                      'asset_bundle': null,
                    },
                  ]
                : [
                    {
                      'id': 'test-0',
                      'title': 'Song',
                      'color': 0xff6f50b9,
                      'available': true,
                      'search_alias': '',
                      'artists': {'name': 'Artist'},
                      'song_units': [
                        {
                          'units': {'name': 'Leo/need'},
                        },
                      ],
                      'charts': [
                        {'difficulty': 3, 'level': 25},
                      ],
                    },
                  ],
          ),
        );
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-key',
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore(client, storage: prefs);
      await store.initialize();
      await store.refresh();
      expect(store.cardCatalog.where((c) => c.id == 9002).length, 1);
      expect(store.cardCatalog.where((c) => c.id == 9001).length, 1);
      await store.setCard(9001, owned: true, wishlist: false);
      dropFirst = true;
      await store.refresh(force: true);
      // A card that disappears upstream stays readable and valid locally.
      expect(store.cardCatalog.where((c) => c.id == 9001).length, 1);
      await store.setCard(9001, owned: false, wishlist: true);
      final reopened = AppStore(null, storage: prefs);
      await reopened.initialize();
      expect(reopened.cardCatalog.where((c) => c.id == 9001).length, 1);
      expect(reopened.cardCatalog.where((c) => c.id == 9002).length, 1);
      expect(reopened.collectionEntry(9001).wishlist, true);
      expect(reopened.songs.single.title, 'Song');
      store.dispose();
      reopened.dispose();
      await client.dispose();
      await subscription.cancel();
      await server.close(force: true);
    }, LoopbackHttpOverrides()),
  );
}
