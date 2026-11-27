import 'dart:io';

const base = String.fromEnvironment(
  'ARTWORK_BASE_URL',
  defaultValue: 'https://storage.sekai.best/sekai-en-assets',
);

Future<void> main() async {
  final client = HttpClient();
  final root = base.replaceFirst(RegExp(r'/+$'), '');
  try {
    for (final path in [
      'music/jacket/jacket_s_001/jacket_s_001.webp',
      'character/character_select/chr_tl_1.webp',
      'character/member/res001_no001/card_normal.webp',
      'character/member/res001_no004/card_after_training.webp',
      'character/member/res008_no049/card_normal.webp',
    ]) {
      final request = await client.getUrl(Uri.parse('$root/$path'));
      final response = await request.close();
      final bytes = await response.fold<List<int>>(
        [],
        (all, chunk) => all..addAll(chunk),
      );
      final webp =
          bytes.length > 12 &&
          String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
      stdout.writeln(
        '${response.statusCode} WEBP=$webp bytes=${bytes.length} $path',
      );
      if (response.statusCode != 200 || !webp) exitCode = 1;
    }
  } finally {
    client.close(force: true);
  }
}
