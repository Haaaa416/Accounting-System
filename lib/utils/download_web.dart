import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// 在瀏覽器觸發檔案下載
Future<bool> saveTextFile(String filename, String content,
    {String mime = 'text/plain'}) async {
  final bytes = utf8.encode(content);
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: '$mime;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
