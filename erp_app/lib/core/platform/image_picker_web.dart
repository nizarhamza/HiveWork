import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

// M-4: Migrated from deprecated dart:html to package:web + dart:js_interop.
Future<({Uint8List bytes, String mimeType})?> pickImageBytes() async {
  final completer = Completer<({Uint8List bytes, String mimeType})?>();

  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = 'image/*'
    ..style.display = 'none';
  web.document.body!.appendChild(input);

  input.addEventListener(
    'change',
    (web.Event _) {
      if (completer.isCompleted) return;
      final files = input.files;
      if (files == null || files.length == 0) {
        input.remove();
        completer.complete(null);
        return;
      }
      final file = files.item(0)!;
      final reader = web.FileReader();

      reader.addEventListener(
        'load',
        (web.Event __) {
          input.remove();
          if (completer.isCompleted) return;
          try {
            final dataUrl = (reader.result as JSString).toDart;
            final bytes   = base64Decode(dataUrl.split(',').last);
            final mime    = file.type.isNotEmpty ? file.type : 'image/png';
            completer.complete((bytes: bytes, mimeType: mime));
          } catch (_) {
            completer.complete(null);
          }
        }.toJS,
      );

      reader.addEventListener(
        'error',
        (web.Event __) {
          input.remove();
          if (!completer.isCompleted) completer.complete(null);
        }.toJS,
      );

      reader.readAsDataURL(file);
    }.toJS,
  );

  input.click();
  return completer.future;
}
