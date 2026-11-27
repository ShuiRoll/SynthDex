import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synthdex/src/artwork.dart';

// Live CDN smoke test, intentionally outside the offline test suite.
// flutter test --platform chrome --dart-define=LIVE_ARTWORK=true test/artwork_browser_test.dart
void main() {
  for (final entry in <String, String>{
    'song jacket': jacketUrl('jacket_s_001')!,
    'character portrait': characterPortraitUrl(1)!,
    'original card': cardArtUrl('res001_no001')!,
    'trained card': cardArtUrl('res001_no004', trained: true)!,
    'recent card': cardArtUrl('res008_no049')!,
  }.entries) {
    testWidgets('Chrome loads ${entry.key}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 240,
            height: 160,
            child: ArtworkImage(url: entry.value, label: entry.key),
          ),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      await tester.runAsync(() async {
        final loaded = Completer<ImageInfo>();
        final stream = image.image.resolve(ImageConfiguration.empty);
        final listener = ImageStreamListener(
          (info, _) {
            if (!loaded.isCompleted) loaded.complete(info);
          },
          onError: (Object error, StackTrace? stack) {
            if (!loaded.isCompleted) loaded.completeError(error, stack);
          },
        );
        stream.addListener(listener);
        try {
          final info = await loaded.future.timeout(const Duration(seconds: 40));
          expect(info.image.width, greaterThan(0));
          expect(info.image.height, greaterThan(0));
          info.dispose();
        } finally {
          stream.removeListener(listener);
        }
      });
      await tester.pump();
      expect(find.byTooltip('Artwork unavailable. Retry'), findsNothing);
      expect(tester.takeException(), isNull);
    }, skip: !const bool.fromEnvironment('LIVE_ARTWORK'));
  }
}
