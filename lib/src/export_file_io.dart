import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes [contents] to a user-visible folder and returns the saved path.
Future<String> saveTextFile(String name, String contents) async {
  Directory? directory;
  try {
    directory = await getDownloadsDirectory();
  } catch (_) {
    // Downloads is unavailable on some mobile platforms; use app documents.
    directory = null;
  }
  directory ??= await getApplicationDocumentsDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$name');
  await file.writeAsString(contents, flush: true);
  return file.path;
}
