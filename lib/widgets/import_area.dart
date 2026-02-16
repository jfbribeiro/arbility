import 'package:flutter/material.dart';

import '../services/arb_import.dart';

/// A drop-zone-style card shown when no files are loaded. Clicking it
/// opens the file picker to import `.arb` files via [importArbFiles].
class ImportArea extends StatefulWidget {
  const ImportArea({super.key});

  @override
  State<ImportArea> createState() => _ImportAreaState();
}

class _ImportAreaState extends State<ImportArea> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () => importArbFiles(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: _hovering
                ? colors.primary.withValues(alpha: 0.06)
                : colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovering
                  ? colors.primary.withValues(alpha: 0.4)
                  : colors.primary.withValues(alpha: 0.15),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 28,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Import ARB files',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Click to browse and select one or more .arb files',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
