import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Сохраняет байты как файл: создаёт временную ссылку Blob и нажимает её.
void saveBytes(List<int> bytes, String filename, String mimeType) {
  final data = Uint8List.fromList(bytes);
  final blob = web.Blob([data.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
