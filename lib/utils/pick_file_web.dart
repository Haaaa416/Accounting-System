import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// 開啟瀏覽器的選檔視窗，回傳檔案文字內容；按取消回傳 null
Future<String?> pickTextFile(List<String> extensions) {
  final completer = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = extensions.map((e) => '.$e').join(',');

  input.onchange = ((web.Event _) {
    final file = input.files?.item(0);
    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    file.text().toDart.then(
      (text) {
        if (!completer.isCompleted) completer.complete(text.toDart);
      },
      onError: (Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );
  }).toJS;

  input.oncancel = ((web.Event _) {
    if (!completer.isCompleted) completer.complete(null);
  }).toJS;

  input.click();
  return completer.future;
}
