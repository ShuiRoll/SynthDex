import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synthdex/src/artwork.dart';
import 'package:synthdex/src/characters.dart';
import 'package:synthdex/src/store.dart';

void main() {
  test(
    'catalog entries have artwork bundles and old caches retain jackets',
    () {
      expect(bundledSongs.every((s) => s.assetBundle.isNotEmpty), true);
      expect(gameCards.every((c) => c.assetBundle.isNotEmpty), true);
      final old = bundledSongs.first.toJson()..remove('asset_bundle');
      expect(Song.fromJson(old).assetBundle, 'jacket_s_001');
      expect(
        jacketUrl('jacket_s_001'),
        '$artworkBase/music/jacket/jacket_s_001/jacket_s_001.webp',
      );
      expect(
        cardArtUrl('res001_no004', trained: true),
        '$artworkBase/character/member/res001_no004/card_after_training.webp',
      );
      expect(
        gameCards
            .where((c) => c.rarity == 'birthday')
            .every((c) => !c.hasTrainedArtwork),
        true,
      );
    },
  );
  testWidgets('missing artwork retains a stable accessible placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 90,
            height: 90,
            child: ArtworkImage(url: null, label: 'Song jacket'),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(tester.getSize(find.byType(ArtworkImage)), const Size(90, 90));
    expect(tester.takeException(), isNull);
  });
  testWidgets('trained switch changes image only and supports enlargement', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: CardArtwork(
              bundle: 'res001_no004',
              label: 'Test card',
              trainable: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<ArtworkImage>(find.byType(ArtworkImage)).url,
      endsWith('card_normal.webp'),
    );
    await tester.tap(find.text('Trained'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ArtworkImage>(find.byType(ArtworkImage)).url,
      endsWith('card_after_training.webp'),
    );
    await tester.tap(find.byType(ArtworkImage));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('Close artwork'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: CardArtwork(
              bundle: 'res001_no001',
              label: 'One star',
              trainable: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trained'), findsNothing);
  });
}
