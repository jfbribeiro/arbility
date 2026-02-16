import 'package:flutter/material.dart';

/// Displays a non-dismissible modal dialog with a spinner and [message].
///
/// Must be paired with [hideLoadingDialog] to close it once the async
/// work is complete.
void showLoadingDialog(
  BuildContext context, {
  String message = 'Processing...',
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(message, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Closes the loading dialog opened by [showLoadingDialog].
void hideLoadingDialog(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}
