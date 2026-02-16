import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import '../providers/arb_project.dart';
import '../config/app_config.dart';
import '../services/arb_import.dart';
import '../services/excel_export.dart';
import '../services/excel_to_arb.dart';
import '../widgets/arb_table.dart';
import '../widgets/expandable_fab.dart';
import '../widgets/file_priority_dialog.dart';
import '../widgets/import_area.dart';

final _log = Logger('HomeScreen');

/// Main screen containing the header bar, the translation table (or import
/// area when empty), and the expandable FAB with import/export actions.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Debounces search input by 300ms to avoid excessive table rebuilds
  /// while the user is still typing.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _log.fine('Search query updated: "$value"');
      setState(() => _searchQuery = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: Consumer<ArbProject>(
        builder: (context, project, _) {
          return ExpandableFab(
            actions: [
              FabAction(
                icon: Icons.file_open_outlined,
                label: 'Import ARB files',
                onPressed: () => importArbFiles(context),
              ),
              if (!project.isEmpty)
                FabAction(
                  icon: Icons.table_chart_outlined,
                  label: 'Export to Excel',
                  onPressed: () => exportToExcel(context, project),
                ),
              FabAction(
                icon: Icons.upload_file_outlined,
                label: 'Convert Excel to ARB',
                onPressed: () => excelToArb(context),
              ),
            ],
          );
        },
      ),
      body: Column(
        children: [
          // Custom header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: BoxDecoration(
              color: colors.surface,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.translate, color: colors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Arbility',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ARB Viewer',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                // Search field
                Consumer<ArbProject>(
                  builder: (context, project, child) {
                    if (project.isEmpty) return const SizedBox.shrink();
                    return child!;
                  },
                  child: SizedBox(
                    width: 260,
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search keys or translations...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: colors.primary.withValues(alpha: 0.6),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: colors.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                onPressed: () {
                                  _debounce?.cancel();
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: colors.primary.withValues(alpha: 0.05),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: colors.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: colors.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: colors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Consumer<ArbProject>(
                  builder: (context, project, _) {
                    if (project.isEmpty) return const SizedBox.shrink();
                    final config = context.read<AppConfig>();
                    final chip = _HeaderChip(
                      icon: Icons.description_outlined,
                      label: '${project.importedFiles.length} files',
                      colors: colors,
                    );
                    if (!config.filePriority) return chip;
                    return Tooltip(
                      message: 'Manage file priority',
                      child: InkWell(
                        onTap: () => FilePriorityDialog.show(context, project),
                        borderRadius: BorderRadius.circular(8),
                        child: chip,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Consumer<ArbProject>(
                  builder: (context, project, _) {
                    if (project.isEmpty) return const SizedBox.shrink();
                    return _HeaderChip(
                      icon: Icons.language,
                      label: '${project.allLocales.length} locales',
                      colors: colors,
                    );
                  },
                ),
                const SizedBox(width: 12),
                Consumer<ArbProject>(
                  builder: (context, project, _) {
                    if (project.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      onPressed: () {
                        _log.info('Clearing all data');
                        project.clear();
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      tooltip: 'Clear all',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade400,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 20),
                    );
                  },
                ),
              ],
            ),
          ),
          // Body
          Expanded(
            child: Consumer<ArbProject>(
              builder: (context, project, _) {
                if (project.isEmpty) {
                  return const SingleChildScrollView(
                    padding: EdgeInsets.all(24),
                    child: ImportArea(),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ArbTable(searchQuery: _searchQuery),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill-shaped chip used in the header bar to display stats like
/// file count and locale count.
class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colors;

  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
