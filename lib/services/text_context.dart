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

/// Prepares text for the translation API without changing what the user sees.
///
/// Splits hyphenated words so the model sees separate tokens
/// (e.g. `lift-shaft` → `lift shaft`).
String normalizeForTranslation(String input) {
  final spaced = input.replaceAll(RegExp(r'(?<=\w)-(?=\w)'), ' ');
  return normalizeText(spaced);
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

final RegExp _wordTokenPattern = RegExp(r"\S+");
final RegExp _trailingPunctuation = RegExp(r'[.,;:!?…]+$');

/// Maps [selection] to the corresponding span in [translation] by proportional
/// word alignment against [sentence].
///
/// The full sentence is translated once; this extracts the slice that lines up
/// with the user's selection so single-word picks match the in-sentence sense
/// (e.g. `gazed` → `miraba`, not isolated `miradas`).
String? alignSelectionInTranslation({
  required String sentence,
  required String selection,
  required String translation,
}) {
  final selIndex = sentence.indexOf(selection);
  if (selIndex < 0) return null;

  final enTokens = _wordTokenPattern.allMatches(sentence).toList();
  final esTokens = _wordTokenPattern.allMatches(translation).toList();
  if (enTokens.isEmpty || esTokens.isEmpty) return null;

  final selEnd = selIndex + selection.length;
  var firstEn = -1;
  var lastEn = -1;
  for (var i = 0; i < enTokens.length; i++) {
    final token = enTokens[i];
    if (token.end > selIndex && token.start < selEnd) {
      firstEn = firstEn == -1 ? i : firstEn;
      lastEn = i;
    }
  }
  if (firstEn == -1) return null;

  final enCount = enTokens.length;
  final esCount = esTokens.length;

  if (firstEn == lastEn) {
    final esIndex = (((firstEn + 0.5) * esCount) / enCount)
        .floor()
        .clamp(0, esCount - 1);
    return _stripTrailingPunctuation(esTokens[esIndex].group(0)!);
  }

  final esFirst = ((firstEn * esCount) / enCount).floor().clamp(0, esCount - 1);
  final esLast =
      (((lastEn + 1) * esCount) / enCount).ceil().clamp(0, esCount) - 1;

  final words = <String>[
    for (var i = esFirst; i <= esLast; i++)
      _stripTrailingPunctuation(esTokens[i].group(0)!),
  ];
  return words.join(' ');
}

String _stripTrailingPunctuation(String word) {
  return word.replaceAll(_trailingPunctuation, '');
}

/// Builds a wider `<b>` span around [selection] with neighbouring words so the
/// NMT model does not treat a lone tagged token in isolation.
class MarkSpan {
  const MarkSpan({
    required this.spanText,
    required this.selectionStartWord,
    required this.selectionWordCount,
  });

  final String spanText;
  final int selectionStartWord;
  final int selectionWordCount;
}

/// Number of words included on each side of the selection inside the mark.
const int markContextWords = 2;

MarkSpan buildMarkSpan(
  String sentence,
  String selection, {
  int contextWords = markContextWords,
}) {
  final selIndex = sentence.indexOf(selection);
  if (selIndex < 0) {
    return MarkSpan(
      spanText: selection,
      selectionStartWord: 0,
      selectionWordCount: _wordTokenPattern.allMatches(selection).length,
    );
  }

  final tokens = _wordTokenPattern.allMatches(sentence).toList();
  final selEnd = selIndex + selection.length;
  var first = -1;
  var last = -1;
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (token.end > selIndex && token.start < selEnd) {
      first = first == -1 ? i : first;
      last = i;
    }
  }

  if (first == -1) {
    return MarkSpan(
      spanText: selection,
      selectionStartWord: 0,
      selectionWordCount: 1,
    );
  }

  final spanStart = (first - contextWords).clamp(0, tokens.length - 1);
  final spanEnd = (last + contextWords).clamp(0, tokens.length - 1);
  final spanWords = <String>[
    for (var i = spanStart; i <= spanEnd; i++) tokens[i].group(0)!,
  ];

  return MarkSpan(
    spanText: spanWords.join(' '),
    selectionStartWord: first - spanStart,
    selectionWordCount: last - first + 1,
  );
}

/// Picks the words inside a marked translation that correspond to the selection.
String? extractSelectionFromMarkedSpan(
  String markedTranslation,
  MarkSpan span,
) {
  final words = _wordTokenPattern
      .allMatches(markedTranslation)
      .map((m) => m.group(0)!)
      .toList();
  if (words.isEmpty) return null;

  final start = span.selectionStartWord.clamp(0, words.length - 1);
  final end = (start + span.selectionWordCount).clamp(0, words.length);
  if (start >= end) return words[start];
  return words.sublist(start, end).join(' ');
}
