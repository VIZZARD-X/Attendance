import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void downloadExcelWeb(Uint8List bytes, String filename) {
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}

Future<Map<String, dynamic>?> pickExcelWeb() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.xlsx'
    ..style.display = 'none';
  web.document.body?.append(input);
  final picked = Completer<web.File?>();
  final cancelSub =
      web.EventStreamProviders.focusEvent.forTarget(web.window).listen((_) {
    Future<void>.delayed(const Duration(milliseconds: 500)).then((_) {
      if (!picked.isCompleted) picked.complete(null);
    });
  });
  input.onChange.first.then((_) => picked.complete(input.files?.item(0)));
  input.click();
  web.File? file;
  try {
    file = await picked.future;
  } finally {
    await cancelSub.cancel();
    input.remove();
  }
  if (file == null) return null;
  
  final buffer = await file.arrayBuffer().toDart;
  final bytes = buffer.toDart.asUint8List();
  
  return {
    'name': file.name,
    'bytes': bytes,
  };
}
