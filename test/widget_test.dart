import 'package:arbility/providers/arb_project.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArbProject.extractLocale', () {
    test('extracts locale after first underscore', () {
      expect(ArbProject.extractLocale('test_DE_de.arb'), 'DE_de');
    });

    test('handles simple locale', () {
      expect(ArbProject.extractLocale('app_en.arb'), 'en');
    });

    test('handles no underscore', () {
      expect(ArbProject.extractLocale('messages.arb'), 'messages');
    });
  });

  group('ArbProject', () {
    test('tracks entries and lookups', () {
      final project = ArbProject();
      project.addEntries([
        ArbEntry(
          key: 'hello',
          value: 'Hello',
          sourceFile: 'app_en.arb',
          locale: 'en',
        ),
        ArbEntry(
          key: 'hello',
          value: 'Hallo',
          sourceFile: 'app_de.arb',
          locale: 'de',
        ),
      ]);

      expect(project.allKeys, {'hello'});
      expect(project.allLocales, {'en', 'de'});

      final result = project.getValue('hello', 'de');
      expect(result?.value, 'Hallo');
      expect(result?.sourceFile, 'app_de.arb');
      expect(result?.isModified, false);

      expect(project.getValue('hello', 'fr'), isNull);
    });

    test('updateValue marks entry as modified', () {
      final project = ArbProject();
      project.addEntries([
        ArbEntry(
          key: 'hello',
          value: 'Hello',
          sourceFile: 'app_en.arb',
          locale: 'en',
        ),
      ]);

      project.updateValue('hello', 'en', 'Hi');
      final result = project.getValue('hello', 'en');
      expect(result?.value, 'Hi');
      expect(result?.originalValue, 'Hello');
      expect(result?.isModified, true);
    });

    test('updateValue back to original is not modified', () {
      final project = ArbProject();
      project.addEntries([
        ArbEntry(
          key: 'hello',
          value: 'Hello',
          sourceFile: 'app_en.arb',
          locale: 'en',
        ),
      ]);

      project.updateValue('hello', 'en', 'Hi');
      project.updateValue('hello', 'en', 'Hello');
      final result = project.getValue('hello', 'en');
      expect(result?.isModified, false);
    });

    test('file priority determines which value wins for duplicates', () {
      final project = ArbProject();
      project.addEntries([
        ArbEntry(
          key: 'title',
          value: 'From A',
          sourceFile: 'a_en.arb',
          locale: 'en',
        ),
        ArbEntry(
          key: 'title',
          value: 'From B',
          sourceFile: 'b_en.arb',
          locale: 'en',
        ),
      ]);

      // a_en.arb was added first, so it has higher priority
      expect(project.getValue('title', 'en')?.value, 'From A');
      expect(project.getValue('title', 'en')?.sourceFile, 'a_en.arb');

      // Reorder: move b_en.arb to index 0 (highest priority)
      project.reorderFiles(1, 0);
      expect(project.getValue('title', 'en')?.value, 'From B');
      expect(project.getValue('title', 'en')?.sourceFile, 'b_en.arb');
    });

    test('clear removes all data', () {
      final project = ArbProject();
      project.addEntries([
        ArbEntry(key: 'k', value: 'v', sourceFile: 'f.arb', locale: 'en'),
      ]);
      project.clear();
      expect(project.isEmpty, true);
    });
  });
}
