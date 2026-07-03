import 'package:flutter/material.dart';

enum TranslationStatus { hidden, loading, shown, error }

/// Floating card that shows the translation of the user's selection.
///
/// The English text is editable so the user can fix PDF extraction glitches
/// (e.g. `frail fi gure` → `frail figure`) and request a new translation.
class TranslationOverlay extends StatefulWidget {
  const TranslationOverlay({
    super.key,
    required this.status,
    required this.selectedText,
    required this.contextSentence,
    required this.onDismiss,
    required this.onRetranslate,
    this.translation,
    this.errorMessage,
  });

  final TranslationStatus status;
  final String selectedText;
  final String contextSentence;
  final String? translation;
  final String? errorMessage;
  final VoidCallback onDismiss;
  final ValueChanged<String> onRetranslate;

  @override
  State<TranslationOverlay> createState() => _TranslationOverlayState();
}

class _TranslationOverlayState extends State<TranslationOverlay> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.selectedText);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(TranslationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedText != oldWidget.selectedText &&
        widget.selectedText != _controller.text) {
      _controller.text = widget.selectedText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.status == TranslationStatus.loading) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onRetranslate(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = widget.status == TranslationStatus.loading;

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
                    onPressed: widget.onDismiss,
                  ),
                ],
              ),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !isLoading,
                minLines: 1,
                maxLines: 4,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Texto en inglés',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Traducir de nuevo',
                    onPressed: isLoading ? null : _submit,
                    icon: isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.translate),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              _buildTranslationLine(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranslationLine(ThemeData theme) {
    switch (widget.status) {
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
          widget.translation ?? '',
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
                widget.errorMessage ?? 'Error al traducir',
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
