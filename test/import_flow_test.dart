import 'dart:convert';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synthdex/src/app.dart';
import 'package:synthdex/src/store.dart';

/// Replaces only the OS file chooser; the rest of the import is the real app.
class FakePicker extends FileSelectorPlatform {
  String? contents;
  int opens = 0;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    opens++;
    final value = contents;
    if (value == null) return null;
    return XFile.fromData(
      utf8.encode(value),
      name: 'synthdex-progress.json',
      mimeType: 'application/json',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  String? snackText(WidgetTester tester) {
    final finder = find.byType(SnackBar);
    if (finder.evaluate().isEmpty) return null;
    final content = tester.widget<SnackBar>(finder.first).content;
    return content is Text ? content.data : 'non-text snackbar';
  }

  String dialogText(WidgetTester tester) =>
      tester.widget<Text>(find.textContaining('This file holds').first).data!;

  /// Shows [store] and opens its Settings page.
  Future<AppStore> openSettings(WidgetTester tester, AppStore store) async {
    await tester.pumpWidget(SynthDexApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    return store;
  }

  /// Opens Settings and taps the import action, leaving the picker result to
  /// [FakePicker.contents]. Returns the app store the UI is backed by.
  Future<AppStore> startImport(
    WidgetTester tester,
    FakePicker picker,
    String? contents, {
    Future<void> Function(AppStore store)? seed,
    bool memoryOnly = true,
  }) async {
    FileSelectorPlatform.instance = picker;
    picker.contents = contents;
    final store = AppStore(null, memoryOnly: memoryOnly);
    await seed?.call(store);
    await openSettings(tester, store);
    await tester.ensureVisible(find.text('Import progress from JSON'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import progress from JSON'));
    await tester.pumpAndSettle();
    return store;
  }

  Future<String> exportJson({
    int attempts = 1,
    int favorites = 0,
    int cards = 0,
  }) async {
    final source = AppStore(null, memoryOnly: true);
    final charts = bundledSongs
        .where((song) => song.available && song.hasChart(3))
        .take(attempts)
        .toList();
    for (var i = 0; i < charts.length; i++) {
      await source.save(charts[i], 3, 1 + (i % 3), i == 0 ? 1000 : null);
    }
    for (final song in charts.take(favorites)) {
      await source.favorite(song);
    }
    for (var i = 0; i < cards; i++) {
      await source.setCard(
        source.cardCatalog.elementAt(i).id,
        owned: i.isEven,
        wishlist: i.isOdd,
      );
    }
    final contents = await source.progressExportJson();
    source.dispose();
    return contents;
  }

  testWidgets('import dialog and toast pluralize one of each record', (
    tester,
  ) async {
    final picker = FakePicker();
    final store = await startImport(
      tester,
      picker,
      await exportJson(attempts: 1, favorites: 1, cards: 1),
    );

    expect(picker.opens, 1);
    expect(
      dialogText(tester),
      startsWith('This file holds 1 attempt, 1 favorite and 1 card.'),
    );
    expect(
      dialogText(tester),
      contains('(currently 0 attempts, 0 favorites and 0 cards)'),
    );
    expect(find.text('Merge'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(
      snackText(tester),
      'Imported 1 attempt, 1 favorite and 1 card (replaced).',
    );
    expect(store.attempts, hasLength(1));
    expect(store.favorites, hasLength(1));
    expect(store.cardCollection, hasLength(1));
    store.dispose();
  });

  testWidgets('import dialog and toast pluralize several records', (
    tester,
  ) async {
    final picker = FakePicker();
    final store = await startImport(
      tester,
      picker,
      await exportJson(attempts: 2, favorites: 2, cards: 2),
    );

    expect(
      dialogText(tester),
      startsWith('This file holds 2 attempts, 2 favorites and 2 cards.'),
    );

    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();
    expect(
      snackText(tester),
      'Imported 2 attempts, 2 favorites and 2 cards (merged).',
    );
    expect(store.attempts, hasLength(2));
    expect(store.favorites, hasLength(2));
    expect(store.cardCollection, hasLength(2));
    expect(store.undoableReplacement, isNull);
    expect(find.text('Undo import'), findsNothing);
    store.dispose();
  });

  testWidgets('a replacing import can be undone from Settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final picker = FakePicker();
    final store = await startImport(
      tester,
      picker,
      await exportJson(attempts: 1, favorites: 1, cards: 1),
      memoryOnly: false,
      seed: (store) async {
        final charts = bundledSongs
            .where((song) => song.available && song.hasChart(3))
            .take(3)
            .toList();
        for (var i = 0; i < 3; i++) {
          await store.save(charts[i], 3, 1, 100 * (i + 1));
        }
      },
    );

    expect(store.attempts, hasLength(3));
    expect(find.text('Undo import'), findsNothing);

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(store.attempts, hasLength(1));
    expect(store.favorites, hasLength(1));
    expect(store.cardCollection, hasLength(1));
    expect(store.undoableReplacement, ReplacementKind.import);
    expect(find.text('Undo import'), findsOneWidget);

    // Let the import toast clear so the undo toast can be asserted.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo import'));
    await tester.pumpAndSettle();
    expect(find.text('Undo import?'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(store.attempts, hasLength(3));
    expect(store.favorites, isEmpty);
    expect(store.cardCollection, isEmpty);
    expect(store.undoableReplacement, isNull);
    expect(find.text('Undo import'), findsNothing);
    expect(
      find.text('Restored the progress from before the last import.'),
      findsOneWidget,
    );
    store.dispose();
  });

  testWidgets('undo survives a restart because the snapshot is on disk', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final contents = await exportJson(attempts: 1);

    final picker = FakePicker();
    final first = await startImport(
      tester,
      picker,
      contents,
      memoryOnly: false,
      seed: (store) async {
        final charts = bundledSongs
            .where((song) => song.available && song.hasChart(3))
            .take(2)
            .toList();
        for (var i = 0; i < 2; i++) {
          await store.save(charts[i], 3, 1, 100 * (i + 1));
        }
      },
    );
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(first.attempts, hasLength(1));
    expect(first.undoableReplacement, ReplacementKind.import);
    first.dispose();

    final reopened = AppStore(null);
    await reopened.initialize();
    expect(reopened.undoableReplacement, ReplacementKind.import);
    await reopened.undoReplacement();
    expect(reopened.attempts, hasLength(2));
    expect(reopened.undoableReplacement, isNull);
    reopened.dispose();
  });

  testWidgets('later progress edits retire the undo offer', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final picker = FakePicker();
    final charts = bundledSongs
        .where((song) => song.available && song.hasChart(3))
        .take(2)
        .toList();
    final store = await startImport(
      tester,
      picker,
      await exportJson(attempts: 1),
      memoryOnly: false,
      seed: (store) => store.save(charts.first, 3, 1, 100),
    );

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(store.undoableReplacement, ReplacementKind.import);

    // Preferences are not progress, so the offer survives them.
    await store.preferences('Test', 3);
    await tester.pumpAndSettle();
    expect(store.undoableReplacement, ReplacementKind.import);
    expect(find.text('Undo import'), findsOneWidget);

    await store.save(charts.last, 3, 1, 900);
    await tester.pumpAndSettle();
    expect(store.undoableReplacement, isNull);
    expect(find.text('Undo import'), findsNothing);
    await expectLater(store.undoReplacement(), throwsA(isA<StateError>()));
    store.dispose();
  });

  testWidgets('a merge import after a replace retires the undo offer', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final chart = bundledSongs.firstWhere(
      (song) => song.available && song.hasChart(3),
    );
    final picker = FakePicker();
    final store = await startImport(
      tester,
      picker,
      await exportJson(attempts: 1),
      memoryOnly: false,
      seed: (store) => store.save(chart, 3, 1, 100),
    );

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(store.undoableReplacement, ReplacementKind.import);
    expect(find.text('Undo import'), findsOneWidget);

    picker.contents = await exportJson(attempts: 2);
    await tester.tap(find.text('Import progress from JSON'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();

    expect(store.undoableReplacement, isNull);
    expect(find.text('Undo import'), findsNothing);
    await expectLater(store.undoReplacement(), throwsA(isA<StateError>()));
    store.dispose();
  });

  testWidgets('a cloud restore can be undone from Settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final charts = bundledSongs
        .where((song) => song.available && song.hasChart(3))
        .take(2)
        .toList();
    final store = AppStore(null);
    await store.save(charts.first, 3, 1, 400);

    // The document a cloud restore would install.
    final backup = AppStore(null, memoryOnly: true);
    await backup.save(charts.last, 3, 1, 900);
    final document = backup.snapshot()..['pending_changes'] = 0;
    backup.dispose();

    await openSettings(tester, store);
    expect(find.text('Undo restore'), findsNothing);

    await store.replaceLocal(document, ReplacementKind.restore, change: false);
    await tester.pumpAndSettle();
    expect(store.best(charts.last.id, 3), 900);
    expect(store.undoableReplacement, ReplacementKind.restore);
    expect(find.text('Undo restore'), findsOneWidget);

    await tester.ensureVisible(find.text('Undo restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo restore'));
    await tester.pumpAndSettle();
    expect(find.text('Undo cloud restore?'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(store.best(charts.first.id, 3), 400);
    expect(store.best(charts.last.id, 3), isNull);
    expect(store.undoableReplacement, isNull);
    expect(find.text('Undo restore'), findsNothing);
    expect(
      find.text('Restored the progress from before the last cloud restore.'),
      findsOneWidget,
    );
    store.dispose();
  });

  testWidgets('resetting local data drops the import undo snapshot', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final picker = FakePicker();
    final store = await startImport(
      tester,
      picker,
      await exportJson(attempts: 1),
      memoryOnly: false,
      seed: (store) async {
        final chart = bundledSongs.firstWhere(
          (song) => song.available && song.hasChart(3),
        );
        await store.save(chart, 3, 1, 100);
      },
    );
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(store.undoableReplacement, ReplacementKind.import);

    await store.reset();
    await tester.pumpAndSettle();
    expect(store.attempts, isEmpty);
    expect(store.undoableReplacement, isNull);
    expect(find.text('Undo import'), findsNothing);
    store.dispose();
  });

  testWidgets('dialog names the local records Replace would delete', (
    tester,
  ) async {
    final picker = FakePicker();
    final store = await startImport(
      tester,
      picker,
      await exportJson(attempts: 1, favorites: 1, cards: 1),
      seed: (store) async {
        final charts = bundledSongs
            .where((song) => song.available && song.hasChart(3))
            .take(4)
            .toList();
        for (var i = 0; i < 3; i++) {
          await store.save(charts[i], 3, 1, 100 * (i + 1));
        }
        await store.favorite(charts[3]);
        for (var i = 0; i < 2; i++) {
          await store.setCard(
            store.cardCatalog.elementAt(i).id,
            owned: true,
            wishlist: false,
          );
        }
      },
    );

    final text = dialogText(tester);
    expect(text, contains('This file holds 1 attempt, 1 favorite and 1 card.'));
    expect(text, contains('(currently 3 attempts, 1 favorite and 2 cards)'));
    expect(find.text('Merge'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(
      snackText(tester),
      'Imported 1 attempt, 1 favorite and 1 card (replaced).',
    );
    expect(store.attempts, hasLength(1));
    expect(store.favorites, hasLength(1));
    expect(store.cardCollection, hasLength(1));
    store.dispose();
  });

  testWidgets('wrong-catalog file shows the error toast and no dialog', (
    tester,
  ) async {
    final picker = FakePicker();
    final doc =
        jsonDecode(await exportJson(attempts: 1)) as Map<String, dynamic>;
    (doc['catalog'] as Map)['commit'] = 'deadbeefcafe';
    final store = await startImport(tester, picker, jsonEncode(doc));

    expect(find.textContaining('This file holds'), findsNothing);
    expect(
      snackText(tester),
      'This file was recorded against a different song catalog (deadbee), '
      'so it was not imported.',
    );
    expect(store.attempts, isEmpty);
    store.dispose();
  });

  testWidgets('malformed file shows the error toast and no dialog', (
    tester,
  ) async {
    final picker = FakePicker();
    final store = await startImport(tester, picker, 'not json');

    expect(find.textContaining('This file holds'), findsNothing);
    expect(snackText(tester), 'This is not a SynthDex progress file.');
    expect(store.attempts, isEmpty);
    store.dispose();
  });

  testWidgets('cancelled picker and cancelled dialog change nothing', (
    tester,
  ) async {
    final picker = FakePicker();
    final store = await startImport(tester, picker, null);

    expect(picker.opens, 1);
    expect(find.textContaining('This file holds'), findsNothing);
    expect(snackText(tester), isNull);

    picker.contents = await exportJson(attempts: 1, favorites: 1, cards: 1);
    await tester.tap(find.text('Import progress from JSON'));
    await tester.pumpAndSettle();
    expect(dialogText(tester), startsWith('This file holds 1 attempt'));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('This file holds'), findsNothing);
    expect(snackText(tester), isNull);
    expect(store.attempts, isEmpty);
    expect(store.favorites, isEmpty);
    expect(store.cardCollection, isEmpty);
    store.dispose();
  });
}
