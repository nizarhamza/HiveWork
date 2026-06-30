import 'dart:io';
import 'dart:typed_data';

bool get canSaveToFolder =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

Future<bool> saveToFolder(String folder, String filename, Uint8List bytes) async {
  if (!canSaveToFolder) return false;
  try {
    final dir = Directory(folder);
    if (!await dir.exists()) await dir.create(recursive: true);
    final sep  = Platform.pathSeparator;
    final path = folder.endsWith(sep) ? '$folder$filename' : '$folder$sep$filename';
    await File(path).writeAsBytes(bytes, flush: true);
    return true;
  } catch (_) {
    return false;
  }
}
