import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/translation.dart';
import '../services/context_translator.dart';
import '../services/text_context.dart';
import '../services/translation_service.dart';
import '../widgets/translation_overlay.dart';

/// Debounce window applied to text selection changes so that dragging to
/// extend a selection does not fire dozens of translation requests.
const _selectionDebounce = Duration(milliseconds: 300);

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.translationProvider,
    required this.fileName,
    this.bytes,
    this.path,
  }) : assert(bytes != null || path != null);

  final TranslationProvider translationProvider;
  final String fileName;
  final Uint8List? bytes;
  final String? path;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  Timer? _debounce;
  String? _lastSelection;
  _OverlayState _overlay = const _OverlayState.hidden();

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Widget _buildPdfViewer() {
    final params = PdfViewerParams(
      textSelectionParams: PdfTextSelectionParams(
        enabled: true,
        onTextSelectionChange: _handleSelectionChange,
      ),
    );
    if (widget.bytes != null) {
      return PdfViewer.data(
        widget.bytes!,
        sourceName: widget.fileName,
        params: params,
      );
    }
    return PdfViewer.file(widget.path!, params: params);
  }

  void _handleSelectionChange(PdfTextSelection selection) {
    _debounce?.cancel();
    _debounce = Timer(_selectionDebounce, () => _processSelection(selection));
  }

  Future<void> _processSelection(PdfTextSelection selection) async {
    if (!mounted) return;
    if (!selection.hasSelectedText) {
      setState(() {
        _overlay = const _OverlayState.hidden();
        _lastSelection = null;
      });
      return;
    }

    final rawSelected = (await selection.getSelectedText()).trim();
    if (!mounted) return;
    if (rawSelected.isEmpty) return;

    final selectedText = normalizeText(rawSelected);
    if (selectedText.isEmpty) return;

    if (selectedText == _lastSelection && _overlay.isVisible) {
      setState(() => _overlay = const _OverlayState.hidden());
      _lastSelection = null;
      return;
    }
    _lastSelection = selectedText;

    final ranges = await selection.getSelectedTextRanges();
    if (!mounted) return;
    final pageText = ranges.isNotEmpty ? ranges.first.pageText.fullText : '';
    final sentence = expandToSentence(selectedText, pageText);

    await _translateSelection(
      selectedText: selectedText,
      contextSentence: sentence,
      pageText: pageText,
    );
  }

  Future<void> _retranslateFromOverlay(String editedText) async {
    final selectedText = normalizeText(editedText);
    if (selectedText.isEmpty || !mounted) return;

    _lastSelection = selectedText;
    final contextSentence = _contextForManualEdit(
      edited: selectedText,
      original: _overlay.selectedText ?? '',
      sentence: _overlay.contextSentence ?? selectedText,
      pageText: _overlay.pageText ?? '',
    );

    await _translateSelection(
      selectedText: selectedText,
      contextSentence: contextSentence,
      pageText: _overlay.pageText ?? '',
    );
  }

  /// Builds context for a user-corrected selection (e.g. fixing `fi gure`).
  String _contextForManualEdit({
    required String edited,
    required String original,
    required String sentence,
    required String pageText,
  }) {
    if (original.isNotEmpty && sentence.contains(original)) {
      return sentence.replaceFirst(original, edited);
    }
    final expanded = expandToSentence(edited, pageText);
    return expanded.isNotEmpty ? expanded : edited;
  }

  Future<void> _translateSelection({
    required String selectedText,
    required String contextSentence,
    required String pageText,
  }) async {
    setState(() {
      _overlay = _OverlayState.loading(
        selectedText: selectedText,
        contextSentence: contextSentence,
        pageText: pageText,
      );
    });

    try {
      final result = await translateSelectionWithContext(
        provider: widget.translationProvider,
        selection: selectedText,
        contextSentence: contextSentence,
        source: 'en',
        target: 'es',
      );
      if (!mounted || _lastSelection != selectedText) return;
      setState(() {
        _overlay = _OverlayState.shown(
          selectedText: selectedText,
          contextSentence: contextSentence,
          pageText: pageText,
          translation: result.translatedText,
        );
      });
    } on TranslationException catch (e) {
      if (!mounted || _lastSelection != selectedText) return;
      setState(() {
        _overlay = _OverlayState.error(
          selectedText: selectedText,
          contextSentence: contextSentence,
          pageText: pageText,
          message: e.message,
        );
      });
    }
  }

  void _dismissOverlay() {
    setState(() {
      _overlay = const _OverlayState.hidden();
      _lastSelection = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileName,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildPdfViewer()),
          if (_overlay.isVisible)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: TranslationOverlay(
                  status: _overlay.status,
                  selectedText: _overlay.selectedText ?? '',
                  contextSentence: _overlay.contextSentence ?? '',
                  translation: _overlay.translation,
                  errorMessage: _overlay.message,
                  onDismiss: _dismissOverlay,
                  onRetranslate: _retranslateFromOverlay,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Simple state container for the translation overlay.
class _OverlayState {
  const _OverlayState._(
    this.status, {
    this.selectedText,
    this.contextSentence,
    this.pageText,
    this.translation,
    this.message,
  });

  const _OverlayState.hidden() : this._(TranslationStatus.hidden);

  const _OverlayState.loading({
    required String selectedText,
    required String contextSentence,
    required String pageText,
  }) : this._(
          TranslationStatus.loading,
          selectedText: selectedText,
          contextSentence: contextSentence,
          pageText: pageText,
        );

  const _OverlayState.shown({
    required String selectedText,
    required String contextSentence,
    required String pageText,
    required String translation,
  }) : this._(
          TranslationStatus.shown,
          selectedText: selectedText,
          contextSentence: contextSentence,
          pageText: pageText,
          translation: translation,
        );

  const _OverlayState.error({
    required String selectedText,
    required String contextSentence,
    required String pageText,
    required String message,
  }) : this._(
          TranslationStatus.error,
          selectedText: selectedText,
          contextSentence: contextSentence,
          pageText: pageText,
          message: message,
        );

  final TranslationStatus status;
  final String? selectedText;
  final String? contextSentence;
  final String? pageText;
  final String? translation;
  final String? message;

  bool get isVisible => status != TranslationStatus.hidden;
}
