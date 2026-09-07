import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/arb_project.dart';
import '../widgets/loading_overlay.dart';

final _log = Logger('ExcelExport');

/// Exports the current [project] translations to an `.xlsx` file and
/// triggers a browser download.
///
/// The spreadsheet contains a header row (`Context | Key | Description |
/// locale1 | locale2 | ...`) followed by one data row per key. A loading
/// dialog is shown during generation.
Future<void> exportToExcel(BuildContext context, ArbProject project) async {
  final outputFilename = await _showExportFilenameDialog(context);
  if (outputFilename == null) {
    _log.info('Excel export cancelled by user before generation');
    return;
  }

  _log.info('Starting Excel export...');
  showLoadingDialog(context, message: 'Exporting to Excel...');

  // Yield a frame so the dialog can paint
  await Future<void>.delayed(Duration.zero);

  final excel = Excel.createExcel();

  // Rename the default sheet to "labels"
  final defaultSheet = excel.getDefaultSheet()!;
  excel.rename(defaultSheet, 'labels');
  final sheet = excel['labels'];

  final config = context.read<AppConfig>();
  final locales = _configuredLocales(config.supportedLocales);
  final keys = project.sortedKeys;

  // Header row
  final headers = ['Context', 'Key', 'Description', ...locales];
  for (var col = 0; col < headers.length; col++) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
    );
    cell.value = TextCellValue(headers[col]);
    cell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );
  }

  // Data rows
  for (var row = 0; row < keys.length; row++) {
    final key = keys[row];
    final dataRow = row + 1;

    // Context: collect source files for this key across all locales
    final sourceFiles = <String>{};
    for (final locale in locales) {
      final result = project.getValue(key, locale);
      if (result != null) {
        sourceFiles.add(result.sourceFile);
      }
    }

    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: dataRow))
        .value = TextCellValue(
      sourceFiles.join(', '),
    );

    // Key
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: dataRow))
        .value = TextCellValue(
      key,
    );

    // Description (empty)
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: dataRow))
        .value = TextCellValue(
      '',
    );

    // Locale values
    for (var col = 0; col < locales.length; col++) {
      final result = project.getValue(key, locales[col]);
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 3 + col, rowIndex: dataRow),
          )
          .value = TextCellValue(
        result?.value ?? '',
      );
    }
  }

  // Set column widths
  sheet.setColumnWidth(0, 30); // Context
  sheet.setColumnWidth(1, 35); // Key
  sheet.setColumnWidth(2, 20); // Description
  for (var col = 0; col < locales.length; col++) {
    sheet.setColumnWidth(3 + col, 40);
  }

  _log.fine('Exported ${keys.length} keys across ${locales.length} locale(s)');

  // On web, save(fileName: ...) triggers a single browser download.
  final bytes = excel.save(fileName: outputFilename);

  if (context.mounted) hideLoadingDialog(context);

  if (bytes == null) {
    _log.severe('Excel encoding returned null');
    return;
  }

  _log.info('Excel file downloaded: $outputFilename (${bytes.length} bytes)');
}

Future<String?> _showExportFilenameDialog(BuildContext context) {
  final controller = TextEditingController(text: 'arbility_export.xlsx');
  String? errorText;

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Export filename'),
            content: SizedBox(
              width: 420,
              child: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Filename',
                  hintText: 'e.g. translations.xlsx',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (errorText != null) setState(() => errorText = null);
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final raw = controller.text.trim();
                  if (raw.isEmpty) {
                    setState(() => errorText = 'Filename must not be empty');
                    return;
                  }
                  final filename = raw.toLowerCase().endsWith('.xlsx')
                      ? raw
                      : '$raw.xlsx';
                  Navigator.of(dialogContext).pop(filename);
                },
                child: const Text('Export'),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(controller.dispose);
}

List<String> _configuredLocales(List<String> locales) {
  final cleaned = locales
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  return cleaned.isNotEmpty ? cleaned : ['en'];
}
