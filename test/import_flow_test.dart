import 'dart:convert';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

  /// Opens Settings and taps the import action, leaving the picker result to
  /// [FakePicker.contents]. Returns the app store the UI is backed by.
  Future<AppStore> startImport(
    WidgetTester tester,
    FakePicker picker,
    String? contents,
  ) async {
    FileSelectorPlatform.instance = picker;
    picker.contents = contents;
    final store = AppStore(null, memoryOnly: true);
    await tester.pumpWidget(SynthDexApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
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
