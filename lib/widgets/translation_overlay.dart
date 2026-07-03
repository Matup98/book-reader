import 'package:flutter/material.dart';

enum TranslationStatus { hidden, loading, shown, error }

/// Floating card that shows the translation of the user's selection.
///
/// The surrounding sentence is used as translation context internally but is
/// intentionally not rendered here — the user only sees the selected word
/// or phrase and its translation.
class TranslationOverlay extends StatelessWidget {
  const TranslationOverlay({
    super.key,
    required this.status,
    required this.selectedText,
    required this.contextSentence,
    required this.onDismiss,
    this.translation,
    this.errorMessage,
  });

  final TranslationStatus status;
  final String selectedText;

  /// Passed for future use (e.g. richer tooltips), but not displayed.
  final String contextSentence;
  final String? translation;
  final String? errorMessage;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Traducción · EN → ES',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close),
                    onPressed: onDismiss,
                  ),
                ],
              ),
              _buildSelectionLine(theme),
              const SizedBox(height: 6),
              _buildBody(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionLine(ThemeData theme) {
    if (selectedText.isEmpty) return const SizedBox.shrink();
    return Text(
      selectedText,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildBody(ThemeData theme) {
    switch (status) {
      case TranslationStatus.loading:
        return Row(
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('Traduciendo…', style: theme.textTheme.bodyMedium),
          ],
        );
      case TranslationStatus.shown:
        return Text(
          translation ?? '',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        );
      case TranslationStatus.error:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                errorMessage ?? 'Error al traducir',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        );
      case TranslationStatus.hidden:
        return const SizedBox.shrink();
    }
  }
}
