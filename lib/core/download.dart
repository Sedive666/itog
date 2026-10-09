// Сохранение файла из памяти. В браузере — через Blob, в тестах — заглушка.
export 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
