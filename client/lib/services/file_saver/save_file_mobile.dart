import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart';

Future<void> saveAndLaunchPdf(List<int> bytes, String fileName) async {
  try {
    final Uint8List byteList = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

    // If running on PC Desktop (Windows, macOS, Linux)
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final String? selectedPath = await FilePicker.saveFile(
        dialogTitle: 'Save Legal Risk Analysis Report PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: byteList,
      );

      if (selectedPath != null && selectedPath.isNotEmpty) {
        final file = File(selectedPath);
        await file.writeAsBytes(byteList, flush: true);
        await OpenFile.open(file.path);
        return;
      }
    }

    // Fallback or Mobile (Android / iOS)
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    } else if (Platform.isIOS) {
      dir = await getApplicationDocumentsDirectory();
    } else {
      dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }

    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    // Open PDF in default viewer / prompt save on mobile and desktop
    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      debugPrint('OpenFile warning: ${result.message}');
    }
  } catch (e) {
    debugPrint('Error saving/launching PDF: $e');
    try {
      final fallbackFile = File('${Directory.systemTemp.path}/$fileName');
      await fallbackFile.writeAsBytes(bytes, flush: true);
      await OpenFile.open(fallbackFile.path);
    } catch (fallbackError) {
      debugPrint('Fallback PDF save also failed: $fallbackError');
      // Both the primary and fallback save attempts failed — throw so the
      // caller's error handling (snackbar, etc.) actually fires instead of
      // silently reporting success.
      throw Exception('Could not save PDF: $e');
    }
  }
}