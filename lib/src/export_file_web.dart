import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Starts a browser download and returns the suggested file name.
Future<String> saveTextFile(String name, String contents) async {
  final blob = web.Blob(
    [contents.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  // Let the download start before releasing the blob URL.
  Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
  return name;
}
