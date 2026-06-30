import 'dart:io';

import 'package:file_selector/file_selector.dart';

Future<String?> pickFolder() async {
  if (Platform.isWindows) {
    // file_selector on Windows often renders behind the Flutter window due to
    // HWND ownership. Delegate to PowerShell which always comes to the front.
    const psCommand = r'''
Add-Type -AssemblyName System.Windows.Forms
$d = New-Object System.Windows.Forms.FolderBrowserDialog
$d.Description = "Select export root folder"
$d.ShowNewFolderButton = $true
if ($d.ShowDialog() -eq "OK") { Write-Output $d.SelectedPath }
''';
    final result = await Process.run(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', psCommand],
    );
    final path = result.stdout.toString().trim();
    return path.isNotEmpty ? path : null;
  }
  if (Platform.isMacOS || Platform.isLinux) {
    return getDirectoryPath(confirmButtonText: 'Select folder');
  }
  return null;
}
