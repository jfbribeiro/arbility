import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

import '../providers/arb_project.dart';
import '../widgets/loading_overlay.dart';

final _log = Logger('ArbDownload');

/// Exports the current project state (including edits and new entries) as
/// `.arb` files packaged in a `.zip` download.
///
/// Original entries are grouped by their source file. New entries (those
/// added via the Add Entry dialog with `sourceFile == 'new-labels'`) are
/// placed into separate `new-labels_<locale>.arb` files.
Future<void> downloadArbFiles(BuildContext context, ArbProject project) async {
  _log.info('Starting ARB file download...');

  showLoadingDialog(context, message: 'Preparing ARB files...');

  // Yield a frame so the dialog can paint
  await Future<void>.delayed(Duration.zero);

  final archive = Archive();

  for (final locale in project.sortedLocales) {
    // Group entries by source file for this locale
    final fileEntries = <String, Map<String, String>>{};

    for (final key in project.sortedKeys) {
      final result = project.getValue(key, locale);
      if (result == null) continue;

      final isNewEntry =
          result.sourceFile.isEmpty || result.sourceFile == 'new-labels';
      final sourceFile = isNewEntry
          ? 'new-labels_$locale.arb'
          : result.sourceFile;

      fileEntries.putIfAbsent(sourceFile, () => {});
      fileEntries[sourceFile]![key] = result.value;
    }

    // Build ARB JSON for each source file
    for (final entry in fileEntries.entries) {
      final filename = entry.key;
      final keys = entry.value.keys.toList()..sort();
      final arbMap = <String, String>{
        '@@locale': locale,
        for (final key in keys) key: entry.value[key]!,
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(arbMap);
      final arbBytes = utf8.encode(jsonStr);

      archive.addFile(ArchiveFile(filename, arbBytes.length, arbBytes));
      _log.fine(
        'Added $filename (${arbBytes.length} bytes, ${keys.length} keys)',
      );
    }
  }

  final zipBytes = ZipEncoder().encode(archive);

  if (context.mounted) hideLoadingDialog(context);

  if (zipBytes == null) {
    _log.severe('Zip encoding returned null');
    return;
  }

  final uint8List = Uint8List.fromList(zipBytes);
  final blob = web.Blob(
    [uint8List.toJS].toJS,
    web.BlobPropertyBag(type: 'application/zip'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = 'arbility_arb_files.zip';
  anchor.click();
  web.URL.revokeObjectURL(url);

  _log.info(
    'Zip downloaded: arbility_arb_files.zip (${zipBytes.length} bytes)',
  );
}
