import 'package:file_selector/file_selector.dart';

/// Reads a SynthDex JSON export chosen by the user, or null when cancelled.
Future<String?> pickProgressFileContents() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'SynthDex progress',
        extensions: ['json'],
        mimeTypes: ['application/json'],
      ),
    ],
  );
  return file?.readAsString();
}
