import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/arb_project.dart';
import '../widgets/loading_overlay.dart';

final _log = Logger('ArbImport');

/// Opens a file picker for `.arb` and `.properties` files, parses each
/// selected file, and adds the resulting entries to the [ArbProject]
/// provided via context.
///
/// A loading dialog is displayed while files are being parsed. Any files
/// that fail to parse are collected and shown in a snackbar at the end.
Future<void> importArbFiles(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['arb', 'properties'],
    allowMultiple: true,
    withData: true,
  );

  if (result == null || !context.mounted) {
    _log.fine('File picker cancelled or context unmounted');
    return;
  }

  final project = context.read<ArbProject>();
  final config = context.read<AppConfig>();
  final messenger = ScaffoldMessenger.of(context);

  final localeOverrides = <String, String>{};
  final localeOptions = _buildLocaleOptions(config.supportedLocales);
  final supportedLocaleSet = localeOptions.map(_normalizeLocale).toSet();

  for (final file in result.files) {
    final filename = file.name;
    final explicitLocale = _extractLocaleIfExplicit(filename);
    if (explicitLocale != null) {
      if (_isSupportedLocale(explicitLocale, supportedLocaleSet)) {
        continue;
      }
      if (!context.mounted) return;

      final selectedLocale = await _showLocalePickerDialog(
        context,
        filename: filename,
        localeOptions: localeOptions,
        invalidLocale: explicitLocale,
      );

      if (selectedLocale == null) {
        _log.info(
          'Locale selection cancelled for "$filename"; aborting import',
        );
        return;
      }

      localeOverrides[filename] = selectedLocale;
      continue;
    }

    if (!context.mounted) return;

    final selectedLocale = await _showLocalePickerDialog(
      context,
      filename: filename,
      localeOptions: localeOptions,
    );

    if (selectedLocale == null) {
      _log.info('Locale selection cancelled for "$filename"; aborting import');
      return;
    }
    localeOverrides[filename] = selectedLocale;
  }

  _log.info('Selected ${result.files.length} file(s) for import');
  showLoadingDialog(context, message: 'Importing translation files...');

  // Yield a frame so the dialog can paint before parsing
  await Future<void>.delayed(Duration.zero);

  final errors = <String>[];
  final allEntries = <ArbEntry>[];

  for (final file in result.files) {
    if (file.bytes == null) continue;

    final filename = file.name;
    final locale =
        localeOverrides[filename] ?? ArbProject.extractLocale(filename);
    _log.fine('Parsing "$filename" (locale: $locale)');

    try {
      final content = utf8.decode(file.bytes!);
      final parsed = _parseTranslationsByExtension(filename, content);
      final countBefore = allEntries.length;

      for (final entry in parsed.entries) {
        if (entry.key.startsWith('@')) continue;
        allEntries.add(
          ArbEntry(
            key: entry.key,
            value: entry.value,
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

List<String> _buildLocaleOptions(List<String> supportedLocales) {
  final cleaned =
      supportedLocales
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  if (cleaned.isNotEmpty) return cleaned;
  return ['en'];
}

String? _extractLocaleIfExplicit(String filename) {
  final lower = filename.toLowerCase();
  final stem = lower.endsWith('.arb')
      ? filename.substring(0, filename.length - 4)
      : lower.endsWith('.properties')
      ? filename.substring(0, filename.length - 11)
      : filename;

  final underscore = stem.indexOf('_');
  if (underscore != -1 && underscore < stem.length - 1) {
    return stem.substring(underscore + 1);
  }

  if (_localeTagPattern.hasMatch(stem)) {
    return stem;
  }

  return null;
}

Future<String?> _showLocalePickerDialog(
  BuildContext context, {
  required String filename,
  required List<String> localeOptions,
  String? invalidLocale,
}) {
  var selected = localeOptions.first;
  final hasInvalidLocale = invalidLocale != null;
  final title = hasInvalidLocale
      ? 'Invalid locale in filename'
      : 'Select locale';
  final helperText = hasInvalidLocale
      ? '"$filename" has invalid locale "$invalidLocale". Please choose a valid locale from the supported list.'
      : '"$filename" has no language in its name. Choose the locale to use for this file.';

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(helperText),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    isExpanded: true,
                    items: [
                      for (final locale in localeOptions)
                        DropdownMenuItem(value: locale, child: Text(locale)),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => selected = value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Locale',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(selected),
                child: const Text('Use locale'),
              ),
            ],
          );
        },
      );
    },
  );
}

final _localeTagPattern = RegExp(r'^[a-z]{2,3}(?:[_-][A-Za-z0-9]{2,8})*$');

String _normalizeLocale(String locale) {
  return locale.trim().replaceAll('_', '-').toLowerCase();
}

bool _isSupportedLocale(String locale, Set<String> supportedLocaleSet) {
  return supportedLocaleSet.contains(_normalizeLocale(locale));
}

Map<String, String> _parseTranslationsByExtension(
  String filename,
  String content,
) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.arb')) {
    final Map<String, dynamic> json = jsonDecode(content);
    return {
      for (final entry in json.entries) entry.key: entry.value.toString(),
    };
  }
  if (lower.endsWith('.properties')) {
    return _parseProperties(content);
  }
  throw FormatException('Unsupported file type: $filename');
}

Map<String, String> _parseProperties(String content) {
  final result = <String, String>{};
  final lines = const LineSplitter().convert(content);

  final current = StringBuffer();
  for (final rawLine in lines) {
    current.write(rawLine);

    if (_endsWithUnescapedBackslash(current.toString())) {
      final cut = current.length - 1;
      final preserved = current.toString().substring(0, cut);
      current
        ..clear()
        ..write(preserved);
      continue;
    }

    final line = current.toString();
    current.clear();

    final trimmedLeft = line.trimLeft();
    if (trimmedLeft.isEmpty ||
        trimmedLeft.startsWith('#') ||
        trimmedLeft.startsWith('!')) {
      continue;
    }

    final parsed = _parsePropertyLine(line);
    if (parsed == null) continue;

    final key = _unescapeProperties(parsed.$1);
    final value = _unescapeProperties(parsed.$2);
    result[key] = value;
  }

  if (current.isNotEmpty) {
    final parsed = _parsePropertyLine(current.toString());
    if (parsed != null) {
      result[_unescapeProperties(parsed.$1)] = _unescapeProperties(parsed.$2);
    }
  }

  return result;
}

bool _isEscapedAt(String s, int index) {
  var slashCount = 0;
  for (var i = index - 1; i >= 0 && s[i] == r'\'; i--) {
    slashCount++;
  }
  return slashCount.isOdd;
}

(String, String)? _parsePropertyLine(String line) {
  var keyEnd = line.length;
  var valueStart = line.length;

  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (_isEscapedAt(line, i)) continue;

    if (ch == '=' || ch == ':') {
      keyEnd = i;
      valueStart = i + 1;
      break;
    }

    if (ch == ' ' || ch == '\t' || ch == '\f') {
      keyEnd = i;
      valueStart = i + 1;
      while (valueStart < line.length) {
        final next = line[valueStart];
        if (next != ' ' && next != '\t' && next != '\f') break;
        valueStart++;
      }
      if (valueStart < line.length &&
          (line[valueStart] == '=' || line[valueStart] == ':')) {
        valueStart++;
      }
      break;
    }
  }

  final rawKey = line.substring(0, keyEnd).trimRight();
  if (rawKey.isEmpty) return null;

  final rawValue = valueStart < line.length ? line.substring(valueStart) : '';
  return (rawKey, rawValue.trimLeft());
}

bool _endsWithUnescapedBackslash(String line) {
  if (line.isEmpty || !line.endsWith(r'\')) return false;
  var slashCount = 0;
  for (var i = line.length - 1; i >= 0 && line[i] == r'\'; i--) {
    slashCount++;
  }
  return slashCount.isOdd;
}

String _unescapeProperties(String value) {
  final out = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final ch = value[i];
    if (ch != r'\') {
      out.write(ch);
      continue;
    }

    if (i + 1 >= value.length) {
      out.write(r'\');
      break;
    }

    final next = value[++i];
    switch (next) {
      case 't':
        out.write('\t');
        break;
      case 'n':
        out.write('\n');
        break;
      case 'r':
        out.write('\r');
        break;
      case 'f':
        out.write('\f');
        break;
      case '\\':
        out.write(r'\');
        break;
      case 'u':
        if (i + 4 < value.length) {
          final hex = value.substring(i + 1, i + 5);
          final code = int.tryParse(hex, radix: 16);
          if (code != null) {
            out.writeCharCode(code);
            i += 4;
            continue;
          }
        }
        out.write(r'\u');
        break;
      default:
        out.write(next);
        break;
    }
  }
  return out.toString();
}
