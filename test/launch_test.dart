import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synthdex/src/launch.dart';
import 'package:synthdex/src/store.dart';
import 'package:synthdex/src/themes.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets('launch renders in light and dark appearance', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('launch-preview'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme('dark', brightness),
            home: const LaunchScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byKey(const Key('launch-preview')),
        matchesGoldenFile('goldens/launch_${brightness.name}.png'),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('launch shows progress until local startup completes', (
    tester,
  ) async {
    final ready = Completer<AppStore>();
    final store = AppStore(null, memoryOnly: true);
    await tester.pumpWidget(SynthDexLaunch(initialize: () => ready.future));
    expect(find.text('Opening your library…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-home')), findsNothing);
    ready.complete(store);
    await tester.pumpAndSettle();
    expect(find.text('Opening your library…'), findsNothing);
    expect(find.byKey(const ValueKey('nav-home')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('startup failure offers retry without resetting saved data', (
    tester,
  ) async {
    var calls = 0;
    final retried = Completer<AppStore>();
    final store = AppStore(null, memoryOnly: true);
    await store.favorite(bundledSongs.first);
    await tester.pumpWidget(
      SynthDexLaunch(
        initialize: () async {
          if (calls++ == 0) throw StateError('Storage temporarily unavailable');
          return retried.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not open your local library.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('Opening your library…'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    retried.complete(store);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nav-home')), findsOneWidget);
    expect(store.favorites, contains('tell-your-world'));
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('launch fits narrow screens with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const LaunchScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
