import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synthdex/src/app.dart';
import 'package:synthdex/src/store.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openSong(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const ValueKey('nav-songs')));
  await tester.enterText(find.byType(TextField), 'Tell Your World');
  await tester.pumpAndSettle();
  await tapVisible(tester, find.text('Tell Your World').last);
}

Future<void> openRecord(WidgetTester tester) =>
    tapVisible(tester, find.text('Record or update selected chart'));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('TC-01 search and manually switch difficulty before recording', (
    tester,
  ) async {
    final store = AppStore(null, memoryOnly: true);
    await tester.pumpWidget(SynthDexApp(store: store));
    await tester.pumpAndSettle();
    await openSong(tester);
    await tapVisible(tester, find.textContaining('MASTER  Lv.'));
    await openRecord(tester);
    expect(find.textContaining('Tell Your World · Master ·'), findsOneWidget);
    await tapVisible(tester, find.text('Save new record'));
    expect(store.attempts.single.difficulty, 4);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets(
    'TC-02 tapping a favorite recommendation opens its selected chart',
    (tester) async {
      final store = AppStore(null, memoryOnly: true);
      await store.favorite(bundledSongs.first);
      await store.updateAppSettings(4, 'dark');
      await tester.pumpWidget(SynthDexApp(store: store));
      await tester.pumpAndSettle();
      expect(store.nextSongs.first.id, 'tell-your-world');
      await tapVisible(tester, find.text('Tell Your World'));
      await openRecord(tester);
      expect(find.textContaining('Tell Your World · Master ·'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'TC-03 and TC-04 guest blank-score Clear survives remount; -100 is rejected',
    (tester) async {
      // No cloud client; storage plugin is mocked. This is an offline-capable
      // widget/persistence test, not an OS network-toggle or process-restart test.
      final store = AppStore(null);
      await store.initialize();
      await tester.pumpWidget(SynthDexApp(store: store));
      await tester.pumpAndSettle();
      await openSong(tester);
      await tapVisible(tester, find.textContaining('EXPERT  Lv.'));
      await openRecord(tester);
      await tapVisible(tester, find.text('Clear'));
      await tester.enterText(find.byType(TextField), '-100');
      await tapVisible(tester, find.text('Save new record'));
      expect(find.text('Enter a valid, non-negative score.'), findsOneWidget);
      expect(store.attempts, isEmpty);
      await tester.enterText(find.byType(TextField), '');
      await tapVisible(tester, find.text('Save new record'));
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      final reopened = AppStore(null);
      await reopened.initialize();
      await tester.pumpWidget(SynthDexApp(store: reopened));
      await tester.pumpAndSettle();
      expect(reopened.signedIn, isFalse);
      expect(reopened.attempts.single.score, isNull);
      expect(reopened.status('tell-your-world', 3), 1);
      await tester.pumpWidget(const SizedBox());
      reopened.dispose();
    },
  );

  test(
    'TC-05 later lower score with higher completion preserves both best values',
    () async {
      final store = AppStore(null, memoryOnly: true);
      await store.save(bundledSongs.first, 3, 1, 950000);
      await store.save(bundledSongs.first, 3, 2, 850000);
      expect(store.best('tell-your-world', 3), 950000);
      expect(store.status('tell-your-world', 3), 2);
      expect(store.attempts, hasLength(2));
      store.dispose();
    },
  );

  testWidgets('TC-06 edit 850000 to 950000 through the history interface', (
    tester,
  ) async {
    final store = AppStore(null, memoryOnly: true);
    await store.save(bundledSongs.first, 3, 1, 850000);
    final original = store.attempts.single;
    await tester.pumpWidget(SynthDexApp(store: store));
    await tester.pumpAndSettle();
    await openSong(tester);
    await tapVisible(tester, find.textContaining('EXPERT  Lv.'));
    await tapVisible(tester, find.text('View progress history'));
    final row = find.ancestor(
      of: find.text('850,000'),
      matching: find.byType(ListTile),
    );
    await tapVisible(tester, row);
    expect(find.text('Edit attempt'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '950000');
    await tapVisible(tester, find.text('Save changes'));
    expect(store.attempts, hasLength(1));
    expect(store.attempts.single.id, original.id);
    expect(store.attempts.single.date, original.date);
    expect(store.best('tell-your-world', 3), 950000);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets(
    'TC-07 Violet Nocturne Dark Expert settings survive app remount',
    (tester) async {
      final store = AppStore(null);
      await store.initialize();
      await store.updateAppSettings(2, 'mint', appearance: 'light');
      await tester.pumpWidget(SynthDexApp(store: store));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('nav-profile')));
      await tapVisible(tester, find.byTooltip('Settings'));
      await tapVisible(tester, find.text('Hard'));
      await tapVisible(tester, find.text('Expert').last);
      await tapVisible(tester, find.text('Mint Reverie'));
      await tapVisible(tester, find.text('Violet Nocturne').last);
      await tapVisible(tester, find.text('Light'));
      await tapVisible(tester, find.text('Dark').last);
      await tapVisible(tester, find.text('Save settings'));
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      final reopened = AppStore(null);
      await reopened.initialize();
      await tester.pumpWidget(SynthDexApp(store: reopened));
      await tester.pumpAndSettle();
      expect(reopened.theme, 'dark');
      expect(reopened.appearance, 'dark');
      expect(reopened.defaultDifficulty, 3);
      expect(
        Theme.of(tester.element(find.byType(Hub))).brightness,
        Brightness.dark,
      );
      await tester.pumpWidget(const SizedBox());
      reopened.dispose();
    },
  );

  testWidgets(
    'TC-08 removing a wishlisted card immediately removes its filtered entry',
    (tester) async {
      final store = AppStore(null);
      await store.initialize();
      await store.setCard(1, owned: false, wishlist: true);
      await tester.pumpWidget(SynthDexApp(store: store));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('nav-roster')));
      await tapVisible(tester, find.text('Cards'));
      await tapVisible(tester, find.text('All cards'));
      await tapVisible(tester, find.text('Wishlist').last);
      expect(find.text('1 matching cards'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('wishlist-1')));
      expect(find.byKey(const ValueKey('wishlist-1')), findsNothing);
      expect(find.text('No cards match these filters.'), findsOneWidget);
      final reopened = AppStore(null);
      await reopened.initialize();
      expect(reopened.collectionEntry(1).wishlist, isFalse);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      reopened.dispose();
    },
  );

  testWidgets(
    'Settings opened from Home returns to Home and shows unsaved hint',
    (tester) async {
      final store = AppStore(null, memoryOnly: true);
      await tester.pumpWidget(SynthDexApp(store: store));
      await tester.pumpAndSettle();
      expect(find.text('Next to play'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Open settings'));
      expect(find.text('App theme'), findsOneWidget);
      expect(find.text('You have unsaved preference changes.'), findsNothing);
      await tapVisible(tester, find.text('Violet Nocturne'));
      await tapVisible(tester, find.text('Mint Reverie').last);
      expect(find.text('You have unsaved preference changes.'), findsOneWidget);
      await tapVisible(tester, find.text('Back'));
      expect(find.text('Next to play'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'Search clear button, difficulty counts, and score-less comparison work',
    (tester) async {
      final store = AppStore(null, memoryOnly: true);
      await store.save(bundledSongs.first, 3, 1, null);
      await store.save(bundledSongs.first, 3, 2, null);
      await tester.pumpWidget(SynthDexApp(store: store));
      await tester.pumpAndSettle();

      // Statistics shows cleared/total and FC count per difficulty
      await tapVisible(tester, find.byKey(const ValueKey('nav-stats')));
      expect(
        find.textContaining('1 / ${store.chartCount(3)} · 1 FC'),
        findsOneWidget,
      );

      // Search clear button resets song query cleanly
      await tapVisible(tester, find.byKey(const ValueKey('nav-songs')));
      await tester.enterText(find.byType(TextField), 'Tell Your World');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Clear search'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Clear search'));
      expect(find.byTooltip('Clear search'), findsNothing);

      // Score-less comparison shows helpful empty-trend message
      await tester.enterText(find.byType(TextField), 'Tell Your World');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Tell Your World').last);
      await tapVisible(tester, find.text('View progress history'));
      await tapVisible(tester, find.text('Compare latest vs previous'));
      expect(
        find.textContaining('No numeric scores recorded yet.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
