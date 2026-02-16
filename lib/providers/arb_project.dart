import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../models/arb_document.dart';

export '../models/arb_document.dart';

final _log = Logger('ArbProject');

/// Central state manager for all imported ARB translation data.
///
/// Holds the raw [ArbEntry] list from imported files, an in-memory
/// edits overlay, and file-priority ordering. Notifies listeners on
/// every mutation so the UI stays in sync.
class ArbProject extends ChangeNotifier {
  final bool filePriorityEnabled;

  ArbProject({this.filePriorityEnabled = true});

  /// Raw entries parsed from imported ARB files.
  final List<ArbEntry> _entries = [];

  /// In-memory edits keyed by `"locale::key"`. These overlay the original
  /// values without modifying [_entries], enabling change tracking.
  final Map<String, String> _edits = {};

  /// Files ordered by priority: first = highest priority.
  /// When two files provide the same key+locale, the higher-priority file wins.
  final List<String> _filePriority = [];

  /// All unique translation keys across every imported file.
  Set<String> get allKeys {
    return _entries.map((e) => e.key).toSet();
  }

  /// All unique locale identifiers across every imported file.
  Set<String> get allLocales {
    return _entries.map((e) => e.locale).toSet();
  }

  /// All unique translation keys, sorted alphabetically.
  List<String> get sortedKeys {
    final keys = allKeys.toList()..sort();
    return keys;
  }

  /// Returns sorted keys filtered by [query], matching against both the
  /// key name and translation values across all locales.
  List<String> filteredSortedKeys(String query) {
    if (query.isEmpty) return sortedKeys;
    final lower = query.toLowerCase();
    return sortedKeys.where((key) {
      if (key.toLowerCase().contains(lower)) return true;
      for (final locale in allLocales) {
        final result = getValue(key, locale);
        if (result != null && result.value.toLowerCase().contains(lower)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  /// All unique locales, sorted alphabetically.
  List<String> get sortedLocales {
    final locales = allLocales.toList()..sort();
    return locales;
  }

  bool get isEmpty => _entries.isEmpty;

  Set<String> get importedFiles => _filePriority.toSet();

  List<String> get filePriority => List.unmodifiable(_filePriority);

  /// Moves a file from [oldIndex] to [newIndex] in the priority list.
  void reorderFiles(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final file = _filePriority.removeAt(oldIndex);
    _filePriority.insert(newIndex, file);
    notifyListeners();
  }

  /// Replaces the entire file-priority order with [newOrder].
  void setFilePriority(List<String> newOrder) {
    _log.info('File priority updated: ${newOrder.join(' > ')}');
    _filePriority
      ..clear()
      ..addAll(newOrder);
    notifyListeners();
  }

  /// Builds the internal map key used to store edits for a given
  /// translation key and locale combination.
  static String _editKey(String key, String locale) => '$locale::$key';

  /// Looks up the current value for [key] in [locale].
  ///
  /// When file-priority is enabled, the entry from the highest-priority
  /// source file wins. Any in-memory edit is layered on top. Returns
  /// `null` only if no imported entry *and* no edit exists.
  ArbLookupResult? getValue(String key, String locale) {
    ArbEntry? bestEntry;

    if (filePriorityEnabled) {
      // Pick the entry from the highest-priority file
      int bestPriority = -1;
      for (final entry in _entries) {
        if (entry.key == key && entry.locale == locale) {
          final priority = _filePriority.indexOf(entry.sourceFile);
          if (bestEntry == null ||
              (priority != -1 && priority < bestPriority)) {
            bestEntry = entry;
            bestPriority = priority;
          }
        }
      }
    } else {
      // No priority: return the first match
      for (final entry in _entries) {
        if (entry.key == key && entry.locale == locale) {
          bestEntry = entry;
          break;
        }
      }
    }

    final ek = _editKey(key, locale);
    final edited = _edits[ek];

    if (bestEntry == null) {
      if (edited == null || edited.isEmpty) return null;
      return ArbLookupResult(
        value: edited,
        originalValue: '',
        sourceFile: '',
        isModified: true,
      );
    }

    final currentValue = edited ?? bestEntry.value;
    final isModified = edited != null && edited != bestEntry.value;
    return ArbLookupResult(
      value: currentValue,
      originalValue: bestEntry.value,
      sourceFile: bestEntry.sourceFile,
      isModified: isModified,
    );
  }

  /// Stores an edit without notifying listeners — used during typing
  /// to avoid rebuilding the entire table on every keystroke.
  void updateValueSilent(String key, String locale, String newValue) {
    _edits[_editKey(key, locale)] = newValue;
  }

  /// Stores an edit and notifies listeners to trigger a UI rebuild.
  void updateValue(String key, String locale, String newValue) {
    _edits[_editKey(key, locale)] = newValue;
    notifyListeners();
  }

  /// Appends new [entries] and registers any previously unseen source
  /// files in the priority list. Notifies listeners when done.
  void addEntries(List<ArbEntry> entries) {
    _entries.addAll(entries);
    final newFiles = <String>[];
    for (final entry in entries) {
      if (!_filePriority.contains(entry.sourceFile)) {
        _filePriority.add(entry.sourceFile);
        newFiles.add(entry.sourceFile);
      }
    }
    _log.info(
      'Added ${entries.length} entries from ${newFiles.length} new file(s)',
    );
    _log.fine(
      'Total: ${_entries.length} entries, ${_filePriority.length} files, ${allKeys.length} keys, ${allLocales.length} locales',
    );
    notifyListeners();
  }

  /// Removes all entries, edits, and file-priority data — resets to
  /// the initial empty state.
  void clear() {
    _log.info('Clearing all data');
    _entries.clear();
    _filePriority.clear();
    _edits.clear();
    notifyListeners();
  }

  /// Extracts the locale identifier from an ARB filename.
  ///
  /// E.g. `"intl_en_US.arb"` → `"en_US"`, `"messages.arb"` → `"messages"`.
  static String extractLocale(String filename) {
    final withoutExt = filename.replaceAll('.arb', '');
    final firstUnderscore = withoutExt.indexOf('_');
    if (firstUnderscore == -1) {
      return withoutExt;
    }
    return withoutExt.substring(firstUnderscore + 1);
  }
}
