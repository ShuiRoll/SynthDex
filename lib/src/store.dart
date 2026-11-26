import 'themes.dart';

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'accounts.dart';
import 'characters.dart';
import 'artwork_data.g.dart';

part 'catalog.g.dart';

const difficulties = ['Easy', 'Normal', 'Hard', 'Expert', 'Master', 'Append'];
const statuses = ['Uncleared', 'Clear', 'Full Combo', 'All Perfect'];

/// Pinned Global master-data snapshot. Keep in sync with
/// `tools/catalog-source/provenance.json`; the export test enforces it.
const catalogSource = 'Sekai-World/sekai-master-db-en-diff';
const catalogCommit = '1ffbf9a3dc6400310987843ce79d7052e199b258';
const catalogPinnedAt = '2026-11-13T07:35:05.247815+00:00';

class Song {
  const Song(
    this.id,
    this.title,
    this.artist,
    this.unit,
    this.color,
    this.levels, {
    this.units = const [],
    this.available = true,
    this.searchAlias = '',
    this.remoteAssetBundle,
  });
  final String? remoteAssetBundle;
  String get assetBundle => remoteAssetBundle ?? songAssetBundles[id] ?? '';
  final String id, title, artist, unit;
  final int color;
  final List<int> levels;
  final List<String> units;
  final bool available;
  final String searchAlias;
  List<String> get unitNames => units.isEmpty ? [unit] : units;
  bool hasChart(int d) => d >= 0 && d < levels.length && levels[d] > 0;
  List<int> get chartDifficulties => [
    for (var d = 0; d < levels.length; d++)
      if (hasChart(d)) d,
  ];
  factory Song.fromJson(Map<String, dynamic> j) => Song(
    j['id'],
    j['title'],
    j['artist'],
    j['unit'],
    j['color'],
    List<int>.from(j['levels']),
    units: List<String>.from(j['units'] ?? []),
    available: j['available'] ?? true,
    searchAlias: j['search_alias'] ?? '',
    remoteAssetBundle: j['asset_bundle'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'unit': unit,
    'color': color,
    'levels': levels,
    'units': unitNames,
    'available': available,
    'search_alias': searchAlias,
    'asset_bundle': assetBundle,
  };
  factory Song.fromCatalog(Map<String, dynamic> j) {
    final levels = List<int>.filled(difficulties.length, 0);
    for (final c in j['charts'] as List) {
      levels[c['difficulty'] as int] = c['level'] as int;
    }
    final units =
        (j['song_units'] as List)
            .map((r) => r['units']['name'] as String)
            .toList()
          ..sort();
    return Song(
      j['id'],
      j['title'],
      j['artists']['name'],
      units.join(' · '),
      j['color'],
      levels,
      units: units,
      available: j['available'],
      searchAlias: j['search_alias'] ?? '',
      remoteAssetBundle: j['asset_bundle'],
    );
  }
}

class Attempt {
  Attempt(
    this.id,
    this.songId,
    this.difficulty,
    this.status,
    this.score,
    this.date,
    this.active,
  );
  final String id, songId;
  final int difficulty, status;
  final int? score;
  final DateTime date;
  final bool active;
  factory Attempt.fromJson(Map<String, dynamic> j) => Attempt(
    j['id'],
    j['song_id'],
    j['difficulty'],
    j['status'],
    j['score'],
    DateTime.parse(j['created_at']),
    j['active'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'song_id': songId,
    'difficulty': difficulty,
    'status': status,
    'score': score,
    'created_at': date.toUtc().toIso8601String(),
    'active': active,
  };
}

String newId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// Which explicit replacement the kept previous document can undo.
enum ReplacementKind { import, restore }

/// Local-first personal data. Authentication is used only by explicit backup actions.
class AppStore extends ChangeNotifier {
  AppStore(this.client, {this._storage, this.memoryOnly = false}) {
    accounts = AccountController(
      client == null ? null : SupabaseAccountBackend(client!),
    );
    subscription = client?.auth.onAuthStateChange.listen(
      (_) => notifyListeners(),
    );
  }
  static const localKey = 'synthdex.personal.v1',
      catalogKey = 'synthdex.catalog.en.v2',
      cardsKey = 'synthdex.cards.en.v1',
      beforeReplaceKey = 'synthdex.before_replace',
      catalogRefreshedKey = 'synthdex.catalog.refreshed.v1';
  final SupabaseClient? client;
  late final AccountController accounts;
  final bool memoryOnly;
  SharedPreferences? _storage;

  /// What the kept pre-replacement document would undo, or null when there is
  /// no offer (nothing kept, or later edits retired it).
  ReplacementKind? undoableReplacement;
  StreamSubscription<AuthState>? subscription;
  Future<void>? _initialization;
  Future<void> _queue = Future.value();
  bool _unreadable = false;
  List<Song> catalog = List.of(bundledSongs);
  List<CharacterCard> cardCatalog = List.of(gameCards);
  List<Song> get songs => catalog.where((song) => song.available).toList();
  Song songById(String id) => catalog.firstWhere((song) => song.id == id);

  /// Remote rows win, while earlier rows are retained so a collection that
  /// references a card the server no longer lists stays readable and valid.
  static List<CharacterCard> _mergeCards(
    List<CharacterCard> remote,
    List<CharacterCard> existing,
  ) {
    final seen = <int>{};
    return [
      for (final card in [...remote, ...existing])
        if (seen.add(card.id) &&
            gameCharacters.any((c) => c.id == card.characterId))
          card,
    ];
  }

  int chartCount([int? difficulty]) => songs.fold(
    0,
    (total, song) =>
        total +
        (difficulty == null
            ? song.chartDifficulties.length
            : (song.hasChart(difficulty) ? 1 : 0)),
  );

  /// A song counts once when any currently tracked chart has a clear or better.
  int get completedSongCount => songs
      .where(
        (song) => song.chartDifficulties.any((d) => status(song.id, d) >= 1),
      )
      .length;
  int get collectedCardCount =>
      cardCollection.values.where((card) => card.owned).length;
  List<Song> get nextSongs {
    final list = songs
        .where(
          (song) =>
              song.hasChart(defaultDifficulty) &&
              status(song.id, defaultDifficulty) < 1,
        )
        .toList();
    list.sort((a, b) {
      final favoriteOrder = (favorites.contains(b.id) ? 1 : 0).compareTo(
        favorites.contains(a.id) ? 1 : 0,
      );
      if (favoriteOrder != 0) return favoriteOrder;
      final levelOrder = a.levels[defaultDifficulty].compareTo(
        b.levels[defaultDifficulty],
      );
      return levelOrder != 0 ? levelOrder : a.title.compareTo(b.title);
    });
    return list.take(3).toList();
  }

  List<Attempt> get recentAttempts => (List<Attempt>.of(
    attempts,
  )..sort((a, b) => b.date.compareTo(a.date))).take(3).toList();
  List<Attempt> _attempts = [];
  List<Attempt> get attempts => UnmodifiableListView(_attempts);
  set attempts(List<Attempt> value) {
    _attempts = value;
    _rebuildProgress();
  }

  final Map<String, Map<int, _ChartProgress>> _progress = {};
  void _rebuildProgress() {
    _progress.clear();
    for (final attempt in _attempts) {
      if (!attempt.active) continue;
      final progress = _progress
          .putIfAbsent(attempt.songId, () => {})
          .putIfAbsent(attempt.difficulty, _ChartProgress.new);
      if (attempt.status > progress.status) progress.status = attempt.status;
      final score = attempt.score;
      if (score != null && (progress.best == null || score > progress.best!)) {
        progress.best = score;
      }
    }
  }

  Set<String> favorites = {};
  Map<int, CollectedCard> cardCollection = {};
  CollectedCard collectionEntry(int id) =>
      cardCollection[id] ?? CollectedCard(id);
  Future<void> setCard(int id, {required bool owned, required bool wishlist}) =>
      _mutate((data) {
        final entries = (data['cards'] as List)
            .where((c) => c['card_id'] != id)
            .toList();
        if (owned || wishlist) {
          entries.add(
            CollectedCard(id, owned: owned, wishlist: wishlist).toJson(),
          );
        }
        data['cards'] = entries;
      });
  String name = '', theme = 'dark', appearance = 'system';
  int defaultDifficulty = 3;
  bool loading = false;
  String? error;
  DateTime? backupAt;
  int pendingChanges = 0;
  DateTime? _catalogRefreshedAt;
  bool get signedIn => client?.auth.currentUser != null;
  bool get _catalogFresh {
    final at = _catalogRefreshedAt;
    return at != null &&
        DateTime.now().toUtc().difference(at) < const Duration(hours: 12);
  }

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    if (memoryOnly) return;
    _storage ??= await SharedPreferences.getInstance();
    undoableReplacement = _readUndoSnapshot();
    _catalogRefreshedAt = DateTime.tryParse(
      _storage!.getString(catalogRefreshedKey) ?? '',
    );
    final catalog = _storage!.getString(catalogKey);
    if (catalog != null) {
      try {
        this.catalog = (jsonDecode(catalog) as List)
            .map((j) => Song.fromJson(Map<String, dynamic>.from(j)))
            .toList();
      } catch (_) {
        this.catalog = List.of(bundledSongs);
      }
    }
    final cachedCards = _storage!.getString(cardsKey);
    if (cachedCards != null) {
      try {
        cardCatalog = _mergeCards(
          [],
          (jsonDecode(cachedCards) as List)
              .map((j) => CharacterCard.fromJson(Map<String, dynamic>.from(j)))
              .toList(),
        );
      } catch (_) {
        cardCatalog = List.of(gameCards);
      }
    }
    final data = _storage!.getString(localKey);
    if (data != null) {
      try {
        final json = Map<String, dynamic>.from(jsonDecode(data));
        _validate(json);
        _apply(json);
      } catch (_) {
        _unreadable = true;
        error = 'Local data could not be read. It has not been overwritten. Restore a backup or reset local data in settings.';
      }
    }
  }

  List<Attempt> history(String id, int d) =>
      attempts.where((a) => a.songId == id && a.difficulty == d).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  int status(String id, int d) => _progress[id]?[d]?.status ?? -1;
  int? best(String id, int d) => _progress[id]?[d]?.best;

  int count(int minimum, [int? difficulty]) {
    var count = 0;
    for (final song in songs) {
      for (final d in song.chartDifficulties) {
        if ((difficulty == null || difficulty == d) &&
            status(song.id, d) >= minimum) {
          count++;
        }
      }
    }
    return count;
  }

  Map<String, dynamic> snapshot() => {
    'version': 1,
    'attempts': attempts.map((a) => a.toJson()).toList(),
    'favorites': favorites.toList(),
    'cards': cardCollection.values.map((c) => c.toJson()).toList(),
    'name': name,
    'difficulty': defaultDifficulty,
    'theme': theme,
    'appearance': appearance,
    'backup_at': backupAt?.toIso8601String(),
    'pending_changes': pendingChanges,
  };

  /// Versioned, account-free progress document. The catalog block records the
  /// snapshot the data was recorded against so a future import can detect drift.
  Future<String> progressExportJson() async {
    await initialize();
    await _queue;
    if (_unreadable) {
      throw StateError(
        'Restore a backup or reset unreadable local data before exporting.',
      );
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'synthdex.progress',
      'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'catalog': {
        'source': catalogSource,
        'commit': catalogCommit,
        'as_of': catalogPinnedAt,
      },
      'attempts': attempts.map((attempt) => attempt.toJson()).toList(),
      'favorites': favorites.toList(),
      'cards': cardCollection.values.map((card) => card.toJson()).toList(),
    });
  }

  /// Parses an exported progress document without touching local data.
  /// Throws [FormatException] for invalid files or a different catalog pin.
  Future<ProgressImport> readProgressFile(String contents) async {
    await initialize();
    await _queue;
    if (_unreadable) {
      throw StateError(
        'Restore a backup or reset unreadable local data before importing.',
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(contents);
    } catch (_) {
      throw const FormatException('This is not a SynthDex progress file.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('This is not a SynthDex progress file.');
    }
    final json = decoded;
    if (json['format'] != 'synthdex.progress') {
      throw const FormatException('This is not a SynthDex progress file.');
    }
    if (json['version'] != 1) {
      throw const FormatException(
        'This progress file uses an unsupported version.',
      );
    }
    final catalog = json['catalog'];
    if (catalog is! Map<String, dynamic> ||
        catalog['source'] is! String ||
        catalog['commit'] is! String) {
      throw const FormatException(
        'This progress file is missing a valid catalog pin.',
      );
    }
    final commit = catalog['commit'] as String;
    if (catalog['source'] != catalogSource || commit != catalogCommit) {
      final short = commit.length > 7 ? commit.substring(0, 7) : commit;
      throw FormatException(
        'This file was recorded against a different song catalog ($short), '
        'so it was not imported.',
      );
    }
    final attempts = json['attempts'];
    final favorites = json['favorites'];
    final cards = json['cards'];
    if (attempts is! List || favorites is! List || cards is! List) {
      throw const FormatException(
        'This progress file is missing progress data.',
      );
    }
    _validateProgress(attempts, favorites, cards);
    return ProgressImport._(
      this,
      attempts.map((raw) => Map<String, dynamic>.from(raw as Map)).toList(),
      List<String>.from(favorites),
      cards.map((raw) => Map<String, dynamic>.from(raw as Map)).toList(),
    );
  }

  void _validate(Map<String, dynamic> data) {
    if (data['version'] != 1 ||
        data['name'] is! String ||
        (data['name'] as String).length > 80 ||
        data['difficulty'] is! int ||
        data['difficulty'] < 0 ||
        data['difficulty'] >= difficulties.length ||
        !validPalette(data['theme']) ||
        !appearanceChoices.contains(data['appearance'] ?? 'system') ||
        data['attempts'] is! List ||
        data['favorites'] is! List) {
      throw const FormatException('Invalid settings or backup format.');
    }
    _validateProgress(
      data['attempts'] as List,
      data['favorites'] as List,
      data['cards'],
    );
  }

  /// Shared record checks for local data and imported progress files.
  void _validateProgress(List attempts, List favorites, Object? cards) {
    if (cards is! List?) {
      throw const FormatException('Invalid card collection.');
    }
    final cardIds = cardCatalog.map((c) => c.id).toSet();
    final seenCards = <int>{};
    for (final raw in cards ?? const []) {
      final CollectedCard card;
      try {
        card = CollectedCard.fromJson(Map<String, dynamic>.from(raw));
      } catch (_) {
        throw const FormatException('Invalid card collection.');
      }
      if (!cardIds.contains(card.cardId) ||
          !seenCards.add(card.cardId) ||
          (!card.owned && !card.wishlist)) {
        throw const FormatException('Invalid card collection.');
      }
    }
    final songIds = catalog.map((s) => s.id).toSet();
    final ids = <String>{};
    for (final raw in attempts) {
      final Attempt a;
      try {
        a = Attempt.fromJson(Map<String, dynamic>.from(raw));
      } catch (_) {
        throw const FormatException('Invalid progress record.');
      }
      if (!RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(a.id) ||
          !ids.add(a.id) ||
          !songIds.contains(a.songId) ||
          a.difficulty < 0 ||
          a.difficulty >= difficulties.length ||
          !songById(a.songId).hasChart(a.difficulty) ||
          a.status < 0 ||
          a.status > 3 ||
          (a.score != null && (a.score! < 0 || a.score! > 2147483647))) {
        throw const FormatException('Invalid progress record.');
      }
    }
    final saved = favorites.whereType<String>().toList();
    if (saved.length != favorites.length ||
        saved.toSet().length != saved.length ||
        !saved.every(songIds.contains)) {
      throw const FormatException('Invalid favorites.');
    }
  }

  void _apply(Map<String, dynamic> json) {
    attempts = (json['attempts'] as List)
        .map((a) => Attempt.fromJson(Map<String, dynamic>.from(a)))
        .toList();
    favorites = Set<String>.from(json['favorites']);
    cardCollection = {
      for (final raw in (json['cards'] ?? []) as List)
        raw['card_id'] as int: CollectedCard.fromJson(
          Map<String, dynamic>.from(raw),
        ),
    };
    name = json['name'];
    defaultDifficulty = json['difficulty'];
    theme = json['theme'];
    appearance = json['appearance'] ?? 'system';
    backupAt = json['backup_at'] is String
        ? DateTime.tryParse(json['backup_at'])
        : null;
    pendingChanges = json['pending_changes'] is int
        ? json['pending_changes']
        : 0;
  }

  Future<void> _persist(Map<String, dynamic> data, {bool change = true}) async {
    if (change) {
      data['pending_changes'] = ((data['pending_changes'] as int?) ?? 0) + 1;
    }
    _validate(data);
    if (!memoryOnly && !await _storage!.setString(localKey, jsonEncode(data))) {
      throw StateError('Could not write local data.');
    }
    _apply(data);
    _unreadable = false;
    error = null;
    notifyListeners();
  }

  Future<void> _mutate(
    void Function(Map<String, dynamic>) edit, {
    bool change = true,
  }) {
    final result = _queue.then((_) async {
      await initialize();
      if (_unreadable) {
        throw StateError(
          'Restore a backup or reset unreadable local data before making changes.',
        );
      }
      final next = snapshot();
      final before = _progressFingerprint(next);
      edit(next);
      // Undo only reaches back to the replacement while nothing has been
      // recorded since, so the first later progress change retires it.
      if (undoableReplacement != null && _progressFingerprint(next) != before) {
        await _clearUndoSnapshot();
      }
      await _persist(next, change: change);
    });
    _queue = result.catchError((Object _) {});
    return result;
  }

  /// The progress-bearing parts of a document. Edits that leave attempts,
  /// favorites and cards alone keep the import undo offer available.
  static String _progressFingerprint(Map<String, dynamic> data) =>
      jsonEncode([data['attempts'], data['favorites'], data['cards']]);

  Future<void> refresh({bool force = false}) async {
    await initialize();
    if (client == null || loading) return;
    if (!force && !memoryOnly && _catalogFresh) return;
    loading = true;
    notifyListeners();
    try {
      final updated = <Song>[];
      // Page explicitly: PostgREST caps responses; do not silently truncate catalogs.
      for (var offset = 0; ; offset += 100) {
        final rows = await client!
            .from('songs')
            .select(
              'id,title,color,available,search_alias,asset_bundle,artists(name),song_units(units(name)),charts(difficulty,level)',
            )
            .order('id')
            .range(offset, offset + 99)
            .timeout(const Duration(seconds: 15));
        updated.addAll(rows.map(Song.fromCatalog));
        if (rows.length < 100) break;
      }
      if (updated.isEmpty) throw const FormatException('Empty remote catalog');
      final updatedCards = <CharacterCard>[];
      for (var offset = 0; ; offset += 1000) {
        final rows = await client!
            .from('character_cards')
            .select('id,character_id,title,rarity_id,attribute_id,asset_bundle')
            .order('id')
            .range(offset, offset + 999)
            .timeout(const Duration(seconds: 15));
        updatedCards.addAll(rows.map(CharacterCard.fromCatalog));
        if (rows.length < 1000) break;
      }
      if (updatedCards.isEmpty) {
        throw const FormatException('Empty remote card roster');
      }
      final nextCards = _mergeCards(updatedCards, cardCatalog);
      final ids = updated.map((song) => song.id).toSet();
      // Keep archived records accessible if an upstream entry is ever withdrawn.
      final retained = catalog
          .where((song) => !ids.contains(song.id))
          .map((song) => Song.fromJson({...song.toJson(), 'available': false}));
      final next = [...updated, ...retained];
      if (!memoryOnly) {
        if (!await _storage!.setString(
          catalogKey,
          jsonEncode(next.map((song) => song.toJson()).toList()),
        )) {
          throw StateError('Could not cache catalog');
        }
        if (!await _storage!.setString(
          cardsKey,
          jsonEncode(nextCards.map((card) => card.toJson()).toList()),
        )) {
          throw StateError('Could not cache card roster');
        }
        _catalogRefreshedAt = DateTime.now().toUtc();
        await _storage!.setString(
          catalogRefreshedKey,
          _catalogRefreshedAt!.toIso8601String(),
        );
      }
      catalog = next;
      cardCatalog = nextCards;
      if (!_unreadable) error = null;
    } catch (_) {
      if (!_unreadable) error = 'Catalog update unavailable. Your local library and progress still work offline.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> favorite(Song song) => _mutate((data) {
    final saved = List<String>.from(data['favorites']);
    if (saved.contains(song.id)) {
      saved.remove(song.id);
    } else {
      saved.add(song.id);
    }
    data['favorites'] = saved;
  });
  Future<void> save(
    Song song,
    int difficulty,
    int status,
    int? score, {
    String? attemptId,
  }) => _mutate((data) {
    final records = List<Map<String, dynamic>>.from(data['attempts']);
    if (attemptId == null) {
      records.add(
        Attempt(
          newId(),
          song.id,
          difficulty,
          status,
          score,
          DateTime.now().toUtc(),
          true,
        ).toJson(),
      );
    } else {
      final index = records.indexWhere((a) => a['id'] == attemptId);
      if (index < 0) throw StateError('That attempt no longer exists.');
      records[index] = {...records[index], 'status': status, 'score': score};
    }
    data['attempts'] = records;
  });
  Future<void> clear(Song song, int difficulty) => _mutate((data) {
    data['attempts'] = (data['attempts'] as List).map((raw) {
      final a = Map<String, dynamic>.from(raw);
      return a['song_id'] == song.id && a['difficulty'] == difficulty
          ? {...a, 'active': false}
          : a;
    }).toList();
  });
  Future<void> deleteAttempt(String id) => _mutate((data) {
    data['attempts'] = (data['attempts'] as List)
        .where((a) => a['id'] != id)
        .toList();
  });
  Future<void> preferences(
    String displayName,
    int difficulty, {
    String? appTheme,
  }) => _mutate((data) {
    data['name'] = displayName.trim();
    data['difficulty'] = difficulty;
    data['theme'] = appTheme ?? theme;
  });
  Future<void> updateDisplayName(String displayName) => _mutate((data) {
    if (!signedIn) throw StateError('Sign in to edit your profile.');
    data['name'] = displayName.trim();
  });
  Future<void> updateAppSettings(
    int difficulty,
    String appTheme, {
    String? appearance,
  }) => _mutate((data) {
    data['difficulty'] = difficulty;
    data['theme'] = appTheme;
    data['appearance'] = appearance ?? this.appearance;
  });

  /// Replaces local data outright, keeping the document it replaces so Settings
  /// can offer an undo. A replacing import and a cloud restore both use this.
  /// [change] follows the caller's pending-change accounting.
  Future<void> replaceLocal(
    Map<String, dynamic> data,
    ReplacementKind kind, {
    required bool change,
  }) {
    final result = _queue.then((_) async {
      await initialize();
      _validate(data);
      final previous = memoryOnly ? null : _storage!.getString(localKey);
      if (previous == null) {
        await _clearUndoSnapshot();
      } else if (!await _storage!.setString(
        beforeReplaceKey,
        jsonEncode({'kind': kind.name, 'document': previous}),
      )) {
        throw StateError('Could not keep the data from before this change.');
      } else {
        undoableReplacement = kind;
      }
      await _persist(data, change: change);
    });
    _queue = result.catchError((Object _) {});
    return result;
  }

  /// The reason recorded with the kept document, or null when there is none or
  /// it cannot be read.
  ReplacementKind? _readUndoSnapshot() {
    if (memoryOnly) return null;
    final raw = _storage!.getString(beforeReplaceKey);
    if (raw == null) return null;
    try {
      final kind = (jsonDecode(raw) as Map)['kind'];
      return ReplacementKind.values.byName(kind as String);
    } catch (_) {
      return null;
    }
  }

  /// Drops the kept document so it can never rewind later edits.
  Future<void> _clearUndoSnapshot() async {
    if (!memoryOnly) await _storage!.remove(beforeReplaceKey);
    undoableReplacement = null;
  }

  /// Puts back the document kept by the last replacing import or cloud restore,
  /// exactly as it was, including preferences and change counters.
  Future<void> undoReplacement() async {
    await initialize();
    await _queue;
    final raw = memoryOnly ? null : _storage!.getString(beforeReplaceKey);
    if (raw == null) {
      throw StateError('There is nothing to undo.');
    }
    final envelope = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final data = Map<String, dynamic>.from(
      jsonDecode(envelope['document'] as String) as Map,
    );
    _validate(data);
    await _clearUndoSnapshot();
    await _persist(data, change: false);
  }

  Future<void> reset() async {
    await initialize();
    await _queue;
    await _clearUndoSnapshot();
    await _persist({
      'version': 1,
      'attempts': <dynamic>[],
      'favorites': <String>[],
      'cards': <dynamic>[],
      'name': '',
      'difficulty': 3,
      'theme': 'dark',
      'appearance': 'system',
      'backup_at': backupAt?.toIso8601String(),
      'pending_changes': pendingChanges,
    });
  }

  String get userId {
    final id = client?.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in to use cloud backups.');
    return id;
  }

  String? get cloudUserId => client?.auth.currentUser?.id;

  Future<void> saveBackup() async {
    await initialize();
    await _queue;
    if (_unreadable) {
      throw StateError('Unreadable local data cannot replace your backup.');
    }
    final uid = userId, data = snapshot(), pendingAtStart = pendingChanges;
    final stamp = await client!.rpc(
      'save_backup_v3',
      params: {
        'p_attempts': data['attempts'],
        'p_favorites': data['favorites'],
        'p_name': data['name'],
        'p_difficulty': data['difficulty'],
        'p_theme': data['theme'],
        'p_appearance': data['appearance'],
        'p_cards': data['cards'],
      },
    );
    if (cloudUserId != uid) {
      throw StateError('Account changed during backup.');
    }
    final at = DateTime.parse(stamp as String).toUtc();
    await _mutate((next) {
      next['backup_at'] = at.toIso8601String();
      // Keep counting edits made while the upload was in flight.
      next['pending_changes'] = max(0, pendingChanges - pendingAtStart);
    }, change: false);
  }

  Future<void> restoreBackup() async {
    await initialize();
    await _queue;
    final uid = userId;
    final raw = await client!.rpc('load_backup_v3');
    if (raw == null) {
      throw StateError('No cloud backup exists for this account yet.');
    }
    if (cloudUserId != uid) {
      throw StateError('Account changed during restore.');
    }
    final data = Map<String, dynamic>.from(raw as Map);
    _validate(data);
    data['backup_at'] = DateTime.tryParse((data['saved_at'] as String?) ?? '')
        ?.toIso8601String();
    data['pending_changes'] = 0;
    await replaceLocal(data, ReplacementKind.restore, change: false);
  }

  Future<DateTime?> cloudBackupAt() async {
    await initialize();
    final id = userId;
    final row = await client!
        .from('backups')
        .select('saved_at')
        .eq('user_id', id)
        .maybeSingle();
    final value = row?['saved_at'];
    return value is String ? DateTime.tryParse(value) : null;
  }

  @override
  void dispose() {
    accounts.dispose();
    subscription?.cancel();
    super.dispose();
  }
}

/// Parsed, validated progress file. [apply] is the only step that writes.
class ProgressImport {
  ProgressImport._(this._store, this._attempts, this._favorites, this._cards);
  final AppStore _store;
  final List<Map<String, dynamic>> _attempts;
  final List<String> _favorites;
  final List<Map<String, dynamic>> _cards;
  int get attemptCount => _attempts.length;
  int get favoriteCount => _favorites.length;
  int get cardCount => _cards.length;

  /// Restores the file's attempts, favorites and cards, either replacing the
  /// local set or merging into it. Preferences and backup metadata are kept.
  /// Replacing keeps the previous document so [AppStore.undoReplacement] can
  /// undo it.
  Future<void> apply({required bool merge}) {
    if (!merge) {
      final next = _store.snapshot();
      next['attempts'] = _attempts;
      next['favorites'] = _favorites;
      next['cards'] = _cards;
      return _store.replaceLocal(next, ReplacementKind.import, change: true);
    }
    return _store._mutate((local) {
      final attemptsById = {
        for (final raw in local['attempts'] as List)
          (raw as Map)['id']: Map<String, dynamic>.from(raw),
      };
      for (final raw in _attempts) {
        attemptsById.putIfAbsent(raw['id'], () => raw);
      }
      local['attempts'] = attemptsById.values.toList();
      local['favorites'] = <String>{
        ...(local['favorites'] as List).cast<String>(),
        ..._favorites,
      }.toList();
      final cards = <int, CollectedCard>{
        for (final raw in local['cards'] as List)
          (raw as Map)['card_id'] as int: CollectedCard.fromJson(
            Map<String, dynamic>.from(raw),
          ),
      };
      for (final raw in _cards) {
        final card = CollectedCard.fromJson(raw);
        final existing = cards[card.cardId];
        final owned = card.owned || (existing?.owned ?? false);
        final wishlist = card.wishlist || (existing?.wishlist ?? false);
        if (owned || wishlist) {
          cards[card.cardId] = CollectedCard(
            card.cardId,
            owned: owned,
            wishlist: wishlist,
          );
        }
      }
      local['cards'] = cards.values.map((card) => card.toJson()).toList();
    });
  }
}

class _ChartProgress {
  int status = -1;
  int? best;
}
