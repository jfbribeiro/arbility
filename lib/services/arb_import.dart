import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import '../providers/arb_project.dart';
import '../widgets/loading_overlay.dart';

final _log = Logger('ArbImport');

/// Opens a file picker for `.arb` files, parses each selected file,
/// and adds the resulting entries to the [ArbProject] provided via context.
///
/// A loading dialog is displayed while files are being parsed. Any files
/// that fail to parse are collected and shown in a snackbar at the end.
Future<void> importArbFiles(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['arb'],
    allowMultiple: true,
    withData: true,
  );

  if (result == null || !context.mounted) {
    _log.fine('File picker cancelled or context unmounted');
    return;
  }

  _log.info('Selected ${result.files.length} file(s) for import');
  showLoadingDialog(context, message: 'Importing ARB files...');

  final project = context.read<ArbProject>();
  final messenger = ScaffoldMessenger.of(context);

  // Yield a frame so the dialog can paint before parsing
  await Future<void>.delayed(Duration.zero);

  final errors = <String>[];
  final allEntries = <ArbEntry>[];

  for (final file in result.files) {
    if (file.bytes == null) continue;

    final filename = file.name;
    final locale = ArbProject.extractLocale(filename);
    _log.fine('Parsing "$filename" (locale: $locale)');

    try {
      final content = utf8.decode(file.bytes!);
      final Map<String, dynamic> json = jsonDecode(content);
      final countBefore = allEntries.length;

      for (final entry in json.entries) {
        if (entry.key.startsWith('@')) continue;
        allEntries.add(
          ArbEntry(
            key: entry.key,
            value: entry.value.toString(),
            sourceFile: filename,
            locale: locale,
          ),
        );
      }
      _log.fine(
        'Parsed ${allEntries.length - countBefore} keys from "$filename"',
      );
    } catch (e) {
      _log.warning('Failed to parse "$filename"', e);
      errors.add('$filename: $e');
    }

    // Yield between files so the dialog can animate
    await Future<void>.delayed(Duration.zero);
  }

  project.addEntries(allEntries);

  if (context.mounted) hideLoadingDialog(context);

  _log.info(
    'Import complete: ${allEntries.length} entries, ${errors.length} error(s)',
  );

  if (errors.isNotEmpty) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Errors parsing: ${errors.join(', ')}'),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
