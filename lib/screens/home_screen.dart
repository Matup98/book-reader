import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/translation.dart';
import '../services/translation_service.dart';
import 'reader_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.translationProvider,
    required this.translationMode,
    required this.onTranslationModeChanged,
    required this.translationEngine,
    required this.onTranslationEngineChanged,
  });

  final TranslationProvider translationProvider;
  final TranslationMode translationMode;
  final ValueChanged<TranslationMode> onTranslationModeChanged;
  final TranslationEngine translationEngine;
  final ValueChanged<TranslationEngine> onTranslationEngineChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _picking = false;

  Future<void> _pickAndOpenPdf() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      final path = file.path;

      if (bytes == null && path == null) {
        _showError('No se pudo leer el archivo.');
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReaderScreen(
            translationProvider: widget.translationProvider,
            translationMode: widget.translationMode,
            onTranslationModeChanged: widget.onTranslationModeChanged,
            translationEngine: widget.translationEngine,
            onTranslationEngineChanged: widget.onTranslationEngineChanged,
            fileName: file.name,
            bytes: bytes,
            path: path,
          ),
        ),
      );
    } catch (e) {
      _showError('Error abriendo el archivo: $e');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Book Reader')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 96,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Leé libros en inglés',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Seleccioná una palabra o una oración para verla traducida al español.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _picking ? null : _pickAndOpenPdf,
                  icon: _picking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.folder_open),
                  label: const Text('Abrir PDF'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Payload used when opening a PDF from bytes.
class PdfBytesSource {
  const PdfBytesSource(this.bytes, this.sourceName);
  final Uint8List bytes;
  final String sourceName;
}
