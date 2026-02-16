import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

final _log = Logger('AppConfig');

/// Application-wide configuration loaded from `assets/configuration.json`.
///
/// Provides feature flags and UI settings that are read once at startup
/// and made available via Provider throughout the widget tree.
class AppConfig {
  /// Whether file-priority conflict resolution is enabled.
  final bool filePriority;

  /// Number of translation rows displayed per page in the table.
  final int pageSize;

  const AppConfig({required this.filePriority, required this.pageSize});

  static const _defaultConfig = AppConfig(filePriority: true, pageSize: 25);

  /// Reads `configuration.json` from the asset bundle and returns an
  /// [AppConfig]. Falls back to sensible defaults if the file is missing
  /// or malformed.
  static Future<AppConfig> load() async {
    try {
      _log.fine('Loading configuration from assets...');
      final jsonStr = await rootBundle.loadString('configuration.json');
      final Map<String, dynamic> json = jsonDecode(jsonStr);
      final config = AppConfig(
        filePriority: json['filePriority'] as bool? ?? true,
        pageSize: json['pageSize'] as int? ?? 25,
      );
      _log.info('Configuration loaded successfully');
      return config;
    } catch (e) {
      _log.warning('Failed to load configuration, using defaults', e);
      return _defaultConfig;
    }
  }
}
