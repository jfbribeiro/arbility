import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

import '../widgets/loading_overlay.dart';

final _log = Logger('ExcelToArb');

/// Converts an Excel file (same format as the export) back into individual
/// `.arb` files packaged as a `.zip` download.
///
/// Flow: file picker → parse Excel → build per-locale ARB JSON → zip →
/// browser download. A loading dialog is shown after file selection.
/// This service is standalone and does not depend on loaded project data.
Future<void> excelToArb(BuildContext context) async {
  _log.info('Starting Excel to ARB conversion...');

  // 1. Pick .xlsx file
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
    withData: true,
  );

  if (result == null || result.files.isEmpty) {
    _log.info('File picker cancelled');
    return;
  }

  final bytes = result.files.single.bytes;
  if (bytes == null) {
    _log.severe('File picker returned no bytes');
    return;
  }

  if (!context.mounted) return;
  showLoadingDialog(context, message: 'Converting Excel to ARB...');

  // Yield a frame so the dialog can paint
  await Future<void>.delayed(Duration.zero);

  _log.fine('Read ${bytes.length} bytes from ${result.files.single.name}');

  // 2. Parse the Excel file
  final excel = Excel.decodeBytes(bytes);
  final sheetName = excel.tables.keys.first;
  final sheet = excel.tables[sheetName]!;
  _log.fine('Parsing sheet "$sheetName" with ${sheet.maxRows} rows');

  if (sheet.maxRows < 2) {
    _log.warning('Sheet has no data rows');
    if (context.mounted) hideLoadingDialog(context);
    return;
  }

  // 3. Read header row: Context | Key | Description | locale1 | locale2 | ...
  final headerRow = sheet.row(0);
  final locales = <String>[];
  for (var col = 3; col < headerRow.length; col++) {
    final cell = headerRow[col];
    final value = cell?.value?.toString() ?? '';
    if (value.isNotEmpty) {
      locales.add(value);
    }
  }

  if (locales.isEmpty) {
    _log.warning('No locale columns found in header');
    if (context.mounted) hideLoadingDialog(context);
    return;
  }

  _log.fine('Found ${locales.length} locale(s): $locales');

  // 4. Build locale -> { key: value } maps
  final localeData = <String, Map<String, String>>{
    for (final locale in locales) locale: {},
  };

  for (var rowIdx = 1; rowIdx < sheet.maxRows; rowIdx++) {
    final row = sheet.row(rowIdx);
    final key = row.length > 1 ? (row[1]?.value?.toString() ?? '') : '';
    if (key.isEmpty) continue;

    for (var col = 0; col < locales.length; col++) {
      final cellIdx = 3 + col;
      final value = row.length > cellIdx
          ? (row[cellIdx]?.value?.toString() ?? '')
          : '';
      localeData[locales[col]]![key] = value;
    }
  }

  _log.fine(
    'Parsed ${localeData.values.first.length} keys across ${locales.length} locale(s)',
  );

  // 5. Generate ARB JSON for each locale and build zip archive
  final archive = Archive();

  for (final locale in locales) {
    final entries = localeData[locale]!;
    final sortedKeys = entries.keys.toList()..sort();
    final arbMap = <String, String>{
      '@@locale': locale,
      for (final key in sortedKeys) key: entries[key]!,
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(arbMap);
    final arbBytes = utf8.encode(jsonStr);

    archive.addFile(ArchiveFile('intl_$locale.arb', arbBytes.length, arbBytes));
    _log.fine('Added intl_$locale.arb (${arbBytes.length} bytes)');
  }

  // 6. Encode zip and trigger download
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
    'Zip downloaded: arbility_arb_files.zip (${zipBytes.length} bytes, ${locales.length} ARB files)',
  );
}
