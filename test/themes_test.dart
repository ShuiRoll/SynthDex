import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synthdex/src/app.dart';
import 'package:synthdex/src/store.dart';
import 'package:synthdex/src/themes.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('every palette has readable light and dark foregrounds', () {
    expect(appPalettes.map((p) => p.name).toSet(), hasLength(8));
    for (final palette in appPalettes) {
      for (final brightness in Brightness.values) {
        final c = buildAppTheme(palette.id, brightness).colorScheme;
        for (final pair in [
          (c.onSurface, c.surface),
          (c.onSurfaceVariant, c.surfaceContainer),
          (c.onPrimary, c.primary),
          (c.primary, c.surface),
          (c.secondary, c.surface),
          (c.tertiary, c.surface),
        ]) {
          expect(
            contrast(pair.$1, pair.$2),
            greaterThanOrEqualTo(4.5),
            reason: '${palette.name} $brightness',
          );
        }
      }
    }
  });

  test('legacy data adopts System; guest choices persist and reset', () async {
    final legacy = AppStore(null, memoryOnly: true).snapshot()
      ..remove('appearance');
    SharedPreferences.setMockInitialValues({
      AppStore.localKey: jsonEncode(legacy),
    });
    final store = AppStore(null);
    await store.initialize();
    expect(store.appearance, 'system');
    await store.updateAppSettings(4, 'mint', appearance: 'light');
    final reloaded = AppStore(null);
    await reloaded.initialize();
    expect(reloaded.theme, 'mint');
    expect(reloaded.appearance, 'light');
    expect(reloaded.defaultDifficulty, 4);
    await expectLater(
      reloaded.updateAppSettings(3, 'invalid'),
      throwsFormatException,
    );
    await expectLater(
      reloaded.updateAppSettings(3, 'mint', appearance: 'invalid'),
      throwsFormatException,
    );
    expect(reloaded.theme, 'mint');
    await reloaded.reset();
    expect(reloaded.theme, 'dark');
    expect(reloaded.appearance, 'system');
    store.dispose();
    reloaded.dispose();
  });

  testWidgets(
    'System responds to device changes and explicit modes override it',
    (tester) async {
      final store = AppStore(null, memoryOnly: true);
      addTearDown(store.dispose);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpWidget(SynthDexApp(store: store));
      await tester.pumpAndSettle();
      Brightness current() =>
          Theme.of(tester.element(find.byType(Hub))).brightness;
      expect(current(), Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(current(), Brightness.dark);
      for (final palette in appPalettes) {
        for (final mode in ['light', 'dark']) {
          await store.updateAppSettings(3, palette.id, appearance: mode);
          await tester.pumpAndSettle();
          expect(
            current(),
            mode == 'light' ? Brightness.light : Brightness.dark,
          );
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
