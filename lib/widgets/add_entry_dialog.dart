import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../providers/arb_project.dart';

final _log = Logger('AddEntryDialog');

/// A dialog that lets the user define a new translation key with values
/// for each loaded locale. The new entry is added to the project on confirm.
class AddEntryDialog extends StatefulWidget {
  final ArbProject project;

  const AddEntryDialog({super.key, required this.project});

  /// Convenience method to show the dialog as a modal.
  static Future<void> show(BuildContext context, ArbProject project) {
    _log.info(
      'Opening add entry dialog (${project.sortedLocales.length} locales)',
    );
    return showDialog(
      context: context,
      builder: (_) => AddEntryDialog(project: project),
    );
  }

  @override
  State<AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<AddEntryDialog> {
  final _keyController = TextEditingController();
  late final Map<String, TextEditingController> _localeControllers;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _localeControllers = {
      for (final locale in widget.project.sortedLocales)
        locale: TextEditingController(),
    };
  }

  @override
  void dispose() {
    _keyController.dispose();
    for (final controller in _localeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onAdd() {
    final key = _keyController.text.trim();

    if (key.isEmpty) {
      setState(() => _errorText = 'Key must not be empty');
      return;
    }

    if (widget.project.allKeys.contains(key)) {
      setState(() => _errorText = 'Key "$key" already exists');
      return;
    }

    final entries = <ArbEntry>[];
    for (final locale in widget.project.sortedLocales) {
      final value = _localeControllers[locale]!.text;
      if (value.isNotEmpty) {
        entries.add(
          ArbEntry(
            key: key,
            value: value,
            sourceFile: 'new-labels',
            locale: locale,
          ),
        );
      }
    }

    _log.info('Adding new entry "$key" with ${entries.length} translation(s)');
    widget.project.addEntries(entries);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_circle_outline, color: colors.primary, size: 22),
          const SizedBox(width: 8),
          const Text('Add New Entry'),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _keyController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Translation key',
                hintText: 'e.g. common_ok_button',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Translations',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _localeControllers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final locale = widget.project.sortedLocales[index];
                  return TextField(
                    controller: _localeControllers[locale],
                    decoration: InputDecoration(
                      labelText: locale,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _onAdd, child: const Text('Add')),
      ],
    );
  }
}
