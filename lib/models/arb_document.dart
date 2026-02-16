/// A single translation entry parsed from an ARB file.
///
/// Each entry represents one key-value pair tied to a specific locale
/// and the source file it was imported from.
class ArbEntry {
  final String key;
  final String value;
  final String sourceFile;
  final String locale;

  const ArbEntry({
    required this.key,
    required this.value,
    required this.sourceFile,
    required this.locale,
  });
}

/// The result of looking up a translation for a given key and locale.
///
/// Contains both the current (possibly edited) value and the original
/// imported value, allowing the UI to track unsaved modifications.
class ArbLookupResult {
  final String value;
  final String originalValue;
  final String sourceFile;
  final bool isModified;

  const ArbLookupResult({
    required this.value,
    required this.originalValue,
    required this.sourceFile,
    required this.isModified,
  });
}
