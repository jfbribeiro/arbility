import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../providers/arb_project.dart';

final _log = Logger('FilePriorityDialog');

/// A dialog that lets the user drag-to-reorder imported ARB files.
///
/// When multiple files contain the same key+locale, the file higher in
/// this list takes priority. Changes are applied to [ArbProject] on confirm.
class FilePriorityDialog extends StatefulWidget {
  final ArbProject project;

  const FilePriorityDialog({super.key, required this.project});

  /// Convenience method to show the dialog as a modal.
  static Future<void> show(BuildContext context, ArbProject project) {
    _log.info(
      'Opening file priority dialog (${project.filePriority.length} files)',
    );
    return showDialog(
      context: context,
      builder: (_) => FilePriorityDialog(project: project),
    );
  }

  @override
  State<FilePriorityDialog> createState() => _FilePriorityDialogState();
}

class _FilePriorityDialogState extends State<FilePriorityDialog> {
  late List<String> _files;

  @override
  void initState() {
    super.initState();
    _files = List.from(widget.project.filePriority);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.swap_vert, color: colors.primary, size: 22),
          const SizedBox(width: 8),
          const Text('File Priority'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Drag to reorder. Files at the top take priority when the same key exists in multiple files.',
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: _files.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) newIndex--;
                    final file = _files.removeAt(oldIndex);
                    _files.insert(newIndex, file);
                  });
                },
                itemBuilder: (context, index) {
                  final file = _files[index];
                  final locale = ArbProject.extractLocale(file);

                  return ReorderableDragStartListener(
                    key: ValueKey(file),
                    index: index,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: index == 0
                            ? colors.primary.withValues(alpha: 0.08)
                            : colors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: index == 0
                              ? colors.primary.withValues(alpha: 0.3)
                              : colors.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.drag_handle,
                            size: 20,
                            color: colors.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              locale.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              file,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: index == 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          if (index == 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'HIGHEST',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
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
        FilledButton(
          onPressed: () {
            _log.info('Applying new file priority order');
            final newOrder = List<String>.from(_files);
            Navigator.of(context).pop();
            widget.project.setFilePriority(newOrder);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
