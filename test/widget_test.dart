import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synthdex/src/app.dart';
import 'package:synthdex/src/store.dart';

class TestStore extends AppStore {
  TestStore() : super(null, memoryOnly: true);
}

class SignedInTestStore extends TestStore {
  bool authenticated = true;
  @override
  bool get signedIn => authenticated;
  void endSession() {
    authenticated = false;
    notifyListeners();
  }
}

void main() {
  testWidgets('Profile navigation stays accessible on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = TestStore();
    await tester.pumpWidget(SynthDexApp(store: store));
    await tester.pumpAndSettle();
    for (final destination in [
      'songs',
      'favorites',
      'stats',
      'roster',
      'profile',
    ]) {
      await tester.tap(find.byKey(ValueKey('nav-$destination')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Sign in / Create account'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('App theme'), findsOneWidget);
    expect(find.text('Export progress as JSON'), findsOneWidget);
    expect(find.text('Import progress from JSON'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in / Create account'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    expect(find.text('Next to play'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  test('best score and completion survive a lower later attempt', () {
    final s = TestStore();
    s.attempts = [
      Attempt('1', 'tell-your-world', 3, 2, 1000, DateTime(2026), true),
      Attempt('2', 'tell-your-world', 3, 1, 500, DateTime(2026, 2), true),
    ];
    expect(s.best('tell-your-world', 3), 1000);
    expect(s.status('tell-your-world', 3), 2);
    expect(s.count(1), 1);
    expect(s.count(2), 1);
    expect(s.count(3), 0);
    s.attempts = [
      Attempt('1', 'tell-your-world', 3, 2, 1000, DateTime(2026), false),
    ];
    expect(s.status('tell-your-world', 3), -1);
    expect(s.best('tell-your-world', 3), null);
    expect(s.history('tell-your-world', 3), hasLength(1));
  });
  testWidgets('search, favorites, record validation and history work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = TestStore();
    await tester.pumpWidget(SynthDexApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Next to play'), findsOneWidget);
    await tester.tap(find.text('Songs'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bug');
    await tester.pumpAndSettle();
    expect(find.text('Tell Your World'), findsNothing);
    await tester.tap(find.byTooltip('Add favorite'));
    await tester.pumpAndSettle();
    expect(store.favorites, contains('bug'));
    await tester.enterText(find.byType(TextField), 'Tell Your World');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tell Your World');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tell Your World').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Record or update selected chart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record or update selected chart'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '-3');
    await tester.ensureVisible(find.text('Save new record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save new record'));
    await tester.pumpAndSettle();
    expect(store.attempts, isEmpty);
    expect(find.text('Enter a valid, non-negative score.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1050000');
    await tester.ensureVisible(find.text('Save new record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save new record'));
    await tester.pumpAndSettle();
    expect(store.attempts.single.score, 1050000);
    expect(find.text('Progress history'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('V2 dashboard renders at mobile size', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('preview'),
        child: SynthDexApp(store: TestStore()),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('preview')),
      matchesGoldenFile('goldens/dashboard.png'),
    );
    for (final entry in [
      ('Songs', 'library'),
      ('Favorites', 'favorites'),
      ('Stats', 'statistics'),
      ('Roster', 'roster'),
    ]) {
      await tester.tap(find.text(entry.$1));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('preview')),
        matchesGoldenFile('goldens/${entry.$2}.png'),
      );
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Songs'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tell Your World');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tell Your World').last);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('preview')),
      matchesGoldenFile('goldens/detail.png'),
    );
    expect(tester.takeException(), isNull);
  });
  test(
    'profile writes require sign-in while settings preserve the display name',
    () async {
      final guest = TestStore();
      await expectLater(guest.updateDisplayName('Guest'), throwsStateError);
      await guest.updateAppSettings(5, 'amoled');
      expect(guest.name, isEmpty);
      expect(guest.defaultDifficulty, 5);
      final member = SignedInTestStore();
      await member.updateDisplayName('Player');
      await member.updateAppSettings(4, 'amoled');
      expect(member.name, 'Player');
      member.endSession();
      await expectLater(member.updateDisplayName('Changed'), throwsStateError);
      expect(member.name, 'Player');
      guest.dispose();
      member.dispose();
    },
  );
  testWidgets('profile and settings stay separate and sign-out hides editing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = SignedInTestStore();
    store.accounts.username = 'Player_1';
    await store.save(bundledSongs.first, 3, 1, 1000);
    await store.save(bundledSongs.first, 4, 2, 2000);
    await store.setCard(1, owned: true, wishlist: false);
    await store.setCard(2, owned: false, wishlist: true);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('profile-preview'),
        child: SynthDexApp(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Profile').first);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('App theme'), findsNothing);
    expect(find.text('Data backup'), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-completed-songs')))
          .data,
      '1 / 647',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-collected-cards')))
          .data,
      '1 / 1256',
    );
    await tester.enterText(
      find.byKey(const Key('profile-display-name')),
      'Rhythm Player',
    );
    await tester.ensureVisible(find.text('Save profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(store.name, 'Rhythm Player');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Profile').first);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('profile-preview')),
      matchesGoldenFile('goldens/profile_signed_in.png'),
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Display name'), findsNothing);
    expect(find.text('App theme'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-display-name')), findsOneWidget);
    store.endSession();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-display-name')), findsNothing);
    expect(find.text('Rhythm Player'), findsNothing);
    expect(find.byKey(const Key('profile-completed-songs')), findsNothing);
    await expectLater(
      find.byKey(const Key('profile-preview')),
      matchesGoldenFile('goldens/profile_guest.png'),
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('profile-preview')),
      matchesGoldenFile('goldens/settings_guest.png'),
    );
    expect(find.text('Save cloud backup'), findsNothing);
    expect(find.text('Sign in for optional backup'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
  testWidgets('guest can change theme and cancel or confirm reset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = TestStore();
    await store.save(bundledSongs.first, 3, 1, 1000);
    await tester.pumpWidget(SynthDexApp(store: store));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Profile').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(store.signedIn, isFalse);
    expect(find.text('Sign in / Create account'), findsOneWidget);
    expect(find.byKey(const Key('profile-display-name')), findsNothing);
    expect(find.text('App theme'), findsNothing);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Display name'), findsNothing);
    await tester.tap(find.text('Violet Nocturne'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Obsidian Violet').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('System (default)'));
    await tester.tap(find.text('System (default)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();
    expect(store.theme, 'amoled');
    expect(store.appearance, 'dark');
    expect(store.name, isEmpty);
    await tester.ensureVisible(find.text('Reset personal data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset personal data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.attempts, hasLength(1));
    await tester.tap(find.text('Reset personal data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset local data'));
    await tester.pumpAndSettle();
    expect(store.attempts, isEmpty);
    expect(store.theme, 'dark');
    expect(store.appearance, 'system');
    expect(tester.takeException(), isNull);
  });
  testWidgets('settings shows durable backup status', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = SignedInTestStore();
    await tester.pumpWidget(SynthDexApp(store: store));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Profile').first);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('No cloud backup yet.'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    store.backupAt = DateTime(2026, 5, 1, 12);
    store.pendingChanges = 2;
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Last backup:'), findsOneWidget);
    expect(find.textContaining('2 changes since'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    store.pendingChanges = 1;
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 change since'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}

