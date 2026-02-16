import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import '../providers/arb_project.dart';
import '../config/app_config.dart';

final _log = Logger('ArbTable');

/// Paginated table displaying all translation keys and their values per
/// locale. Supports inline editing — each cell is a text field whose
/// changes are stored in [ArbProject]'s edit overlay.
class ArbTable extends StatefulWidget {
  static const double keyColumnWidth = 220;
  static const double localeColumnWidth = 320;

  final String searchQuery;

  const ArbTable({super.key, this.searchQuery = ''});

  @override
  State<ArbTable> createState() => _ArbTableState();
}

class _ArbTableState extends State<ArbTable> {
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant ArbTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset to first page when search changes
    if (widget.searchQuery != oldWidget.searchQuery) {
      _log.fine('Search changed, resetting to page 0');
      _currentPage = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ArbProject>(
      builder: (context, project, _) {
        if (project.isEmpty) return const SizedBox.shrink();

        final allKeys = project.filteredSortedKeys(widget.searchQuery);
        final locales = project.sortedLocales;
        final colors = Theme.of(context).colorScheme;
        final pageSize = context.read<AppConfig>().pageSize;

        final totalPages = (allKeys.length / pageSize).ceil();
        // Clamp current page
        if (_currentPage >= totalPages && totalPages > 0) {
          _currentPage = totalPages - 1;
        }

        final startIndex = _currentPage * pageSize;
        final endIndex = (startIndex + pageSize).clamp(0, allKeys.length);
        final pageKeys = allKeys.sublist(startIndex, endIndex);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Table
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width:
                      ArbTable.keyColumnWidth +
                      ArbTable.localeColumnWidth * locales.length,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        decoration: BoxDecoration(color: colors.primary),
                        child: Row(
                          children: [
                            _headerCell('KEY', ArbTable.keyColumnWidth),
                            ...locales.map(
                              (l) => _localeHeaderCell(
                                l,
                                ArbTable.localeColumnWidth,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Rows
                      ...List.generate(pageKeys.length, (i) {
                        final key = pageKeys[i];
                        final isEven = i.isEven;

                        return Container(
                          decoration: BoxDecoration(
                            color: isEven
                                ? colors.surface
                                : colors.primary.withValues(alpha: 0.03),
                            border: Border(
                              bottom: BorderSide(
                                color: colors.primary.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Key cell
                                Container(
                                  width: ArbTable.keyColumnWidth,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: colors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    key,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colors.primary.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                // Locale cells
                                ...locales.map((locale) {
                                  final result = project.getValue(key, locale);
                                  return _EditableCell(
                                    key: ValueKey('$key::$locale'),
                                    width: ArbTable.localeColumnWidth,
                                    entryKey: key,
                                    locale: locale,
                                    originalValue: result?.originalValue ?? '',
                                    initialValue: result?.value ?? '',
                                    sourceFile: result?.sourceFile ?? '',
                                    hasEntry: result != null,
                                    borderColor: colors.primary.withValues(
                                      alpha: 0.06,
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            // Pagination
            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _PaginationBar(
                  currentPage: _currentPage,
                  totalPages: totalPages,
                  totalItems: allKeys.length,
                  pageSize: pageSize,
                  onPageChanged: (page) {
                    _log.fine('Page changed to ${page + 1}/$totalPages');
                    setState(() => _currentPage = page);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  /// Builds a plain header cell with uppercased [text].
  Widget _headerCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Builds a header cell for a locale column, including a flag emoji
  /// when a matching country code can be derived.
  Widget _localeHeaderCell(String locale, double width) {
    final flag = _localeToFlag(locale);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            locale.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          if (flag != null) ...[
            const SizedBox(width: 6),
            Text(flag, style: const TextStyle(fontSize: 14)),
          ],
        ],
      ),
    );
  }

  /// Maps ISO 639-1 language codes to ISO 3166-1 country codes for
  /// languages where the language code alone doesn't match a country.
  static const _langToCountry = {
    'EN': 'GB',
    'JA': 'JP',
    'KO': 'KR',
    'ZH': 'CN',
    'HI': 'IN',
    'UR': 'PK',
    'AR': 'SA',
    'FA': 'IR',
    'HE': 'IL',
    'UK': 'UA',
    'EL': 'GR',
    'CS': 'CZ',
    'DA': 'DK',
    'SV': 'SE',
    'NB': 'NO',
    'NN': 'NO',
    'ET': 'EE',
    'SL': 'SI',
    'VI': 'VN',
    'MS': 'MY',
    'TL': 'PH',
    'SW': 'KE',
    'KA': 'GE',
    'HY': 'AM',
    'SQ': 'AL',
    'BS': 'BA',
    'SR': 'RS',
    'MK': 'MK',
    'GA': 'IE',
    'CY': 'GB',
    'EU': 'ES',
    'GL': 'ES',
    'CA': 'ES',
    'BN': 'BD',
    'TA': 'IN',
    'TE': 'IN',
    'ML': 'IN',
    'KN': 'IN',
    'MR': 'IN',
    'GU': 'IN',
    'PA': 'IN',
    'SI': 'LK',
    'NE': 'NP',
    'MY': 'MM',
    'KM': 'KH',
    'LO': 'LA',
  };

  /// Converts a locale string (e.g. `"en"`, `"pt_BR"`) into a flag emoji.
  /// Returns `null` if no valid two-letter country code can be determined.
  static String? _localeToFlag(String locale) {
    final upper = locale.toUpperCase();
    final parts = upper.split('_');

    String countryCode;
    if (parts.length > 1) {
      countryCode = parts.last.length == 2 ? parts.last : parts.first;
    } else {
      countryCode = _langToCountry[parts.first] ?? parts.first;
    }

    if (countryCode.length != 2) return null;

    final first = 0x1F1E6 + countryCode.codeUnitAt(0) - 0x41;
    final second = 0x1F1E6 + countryCode.codeUnitAt(1) - 0x41;
    return String.fromCharCode(first) + String.fromCharCode(second);
  }
}

/// Compact pagination controls showing the current range, page numbers,
/// and first/prev/next/last navigation buttons.
class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final start = currentPage * pageSize + 1;
    final end = ((currentPage + 1) * pageSize).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$start–$end of $totalItems',
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 16),
          _PageButton(
            icon: Icons.first_page,
            onPressed: currentPage > 0 ? () => onPageChanged(0) : null,
          ),
          const SizedBox(width: 4),
          _PageButton(
            icon: Icons.chevron_left,
            onPressed: currentPage > 0
                ? () => onPageChanged(currentPage - 1)
                : null,
          ),
          const SizedBox(width: 8),
          // Page numbers
          ..._buildPageNumbers(colors),
          const SizedBox(width: 8),
          _PageButton(
            icon: Icons.chevron_right,
            onPressed: currentPage < totalPages - 1
                ? () => onPageChanged(currentPage + 1)
                : null,
          ),
          const SizedBox(width: 4),
          _PageButton(
            icon: Icons.last_page,
            onPressed: currentPage < totalPages - 1
                ? () => onPageChanged(totalPages - 1)
                : null,
          ),
        ],
      ),
    );
  }

  /// Generates a sliding window of up to 5 clickable page number buttons
  /// centered around the current page.
  List<Widget> _buildPageNumbers(ColorScheme colors) {
    final pages = <Widget>[];
    const maxVisible = 5;

    int start = (currentPage - maxVisible ~/ 2).clamp(0, totalPages - 1);
    int end = (start + maxVisible).clamp(0, totalPages);
    if (end - start < maxVisible) {
      start = (end - maxVisible).clamp(0, totalPages - 1);
    }

    for (int i = start; i < end; i++) {
      final isActive = i == currentPage;
      pages.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: InkWell(
            onTap: isActive ? null : () => onPageChanged(i),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive
                    ? colors.primary
                    : colors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? Colors.white
                      : colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return pages;
  }
}

class _PageButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _PageButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onPressed != null;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? colors.onSurface.withValues(alpha: 0.6)
              : colors.onSurface.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

/// A single table cell containing an editable text field for one
/// key+locale combination. Tracks whether the value has been modified
/// from its original imported value and highlights changes in green.
class _EditableCell extends StatefulWidget {
  final double width;
  final String entryKey;
  final String locale;
  final String originalValue;
  final String initialValue;
  final String sourceFile;
  final bool hasEntry;
  final Color borderColor;

  const _EditableCell({
    super.key,
    required this.width,
    required this.entryKey,
    required this.locale,
    required this.originalValue,
    required this.initialValue,
    required this.sourceFile,
    required this.hasEntry,
    required this.borderColor,
  });

  @override
  State<_EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<_EditableCell> {
  late TextEditingController _controller;
  late bool _isModified;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _isModified = _controller.text != widget.originalValue;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Called on every keystroke — stores the edit silently (without
  /// rebuilding the table) and updates the local modified indicator.
  void _onTextChanged(String value) {
    final modified = value != widget.originalValue;
    if (modified != _isModified) {
      setState(() => _isModified = modified);
    }
    context.read<ArbProject>().updateValueSilent(
      widget.entryKey,
      widget.locale,
      value,
    );
  }

  /// Persists the edit when the cell loses focus, ensuring the value
  /// is saved even if the user clicks away without typing further.
  void _onFocusChange(bool focused) {
    if (!focused) {
      context.read<ArbProject>().updateValueSilent(
        widget.entryKey,
        widget.locale,
        _controller.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tooltipMessage = !widget.hasEntry
        ? 'No translation for this locale'
        : _isModified
        ? 'Original: ${widget.originalValue}'
        : 'Source: ${widget.sourceFile}';

    return Tooltip(
      message: tooltipMessage,
      waitDuration: const Duration(milliseconds: 400),
      child: Container(
        width: widget.width,
        decoration: BoxDecoration(
          color: _isModified ? const Color(0x1A4CAF50) : null,
          border: Border(right: BorderSide(color: widget.borderColor)),
        ),
        alignment: Alignment.topLeft,
        child: Focus(
          onFocusChange: _onFocusChange,
          child: TextField(
            controller: _controller,
            maxLines: null,
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurface.withValues(alpha: 0.8),
              height: 1.4,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              hintText: widget.hasEntry ? null : '—',
              hintStyle: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.25),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(
                  color: colors.primary.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
            ),
            onChanged: _onTextChanged,
          ),
        ),
      ),
    );
  }
}
