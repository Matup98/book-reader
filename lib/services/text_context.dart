/// Sentence terminators recognised when expanding a selection.
///
/// Kept as a `Set<int>` of code units for fast lookup during a single pass.
final Set<int> _sentenceTerminators = {
  '.'.codeUnitAt(0),
  '!'.codeUnitAt(0),
  '?'.codeUnitAt(0),
  // Also treat some unicode terminators used in many books.
  '\u2026'.codeUnitAt(0), // …
  '\u3002'.codeUnitAt(0), // 。
};

/// Normalises whitespace so that PDF-extracted text (which often contains
/// arbitrary line breaks) can be searched and expanded reliably.
///
/// - Collapses any run of whitespace (spaces, tabs, newlines) into a single
///   space.
/// - Trims the result.
String normalizeText(String input) {
  return input.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Expands [selected] to the sentence that contains it inside [pageText].
///
/// The lookup is done on normalised copies of both strings so that soft line
/// breaks in the PDF do not prevent matches. If [selected] cannot be found,
/// the original selection is returned unchanged.
String expandToSentence(String selected, String pageText) {
  final normalizedSelection = normalizeText(selected);
  if (normalizedSelection.isEmpty) return selected;

  final normalizedPage = normalizeText(pageText);
  final index = normalizedPage.indexOf(normalizedSelection);
  if (index < 0) return normalizedSelection;

  final selectionEnd = index + normalizedSelection.length;
  final start = _findSentenceStart(normalizedPage, index);
  final end = _findSentenceEnd(normalizedPage, selectionEnd);
  return normalizedPage.substring(start, end).trim();
}

/// Expands [selected] to the paragraph that contains it inside [pageText].
///
/// Unlike [expandToSentence], this preserves the raw [pageText] so that the
/// original line breaks can be used as paragraph boundaries. Paragraphs are
/// separated by blank lines or by two or more consecutive newlines.
String expandToParagraph(String selected, String pageText) {
  final normalizedSelection = normalizeText(selected);
  if (normalizedSelection.isEmpty) return selected;

  final flatPage = pageText.replaceAll('\r\n', '\n');
  final paragraphs = flatPage.split(RegExp(r'\n\s*\n'));
  for (final paragraph in paragraphs) {
    if (normalizeText(paragraph).contains(normalizedSelection)) {
      return normalizeText(paragraph);
    }
  }
  return normalizedSelection;
}

int _findSentenceStart(String text, int selectionStart) {
  for (var i = selectionStart - 1; i >= 0; i--) {
    if (_sentenceTerminators.contains(text.codeUnitAt(i))) {
      return _skipLeadingWhitespace(text, i + 1);
    }
  }
  return 0;
}

int _findSentenceEnd(String text, int selectionEnd) {
  for (var i = selectionEnd; i < text.length; i++) {
    if (_sentenceTerminators.contains(text.codeUnitAt(i))) {
      return i + 1;
    }
  }
  return text.length;
}

int _skipLeadingWhitespace(String text, int from) {
  var i = from;
  while (i < text.length && _isWhitespace(text.codeUnitAt(i))) {
    i++;
  }
  return i;
}

bool _isWhitespace(int codeUnit) {
  return codeUnit == 0x20 || // space
      codeUnit == 0x09 || // tab
      codeUnit == 0x0A || // \n
      codeUnit == 0x0D; // \r
}
