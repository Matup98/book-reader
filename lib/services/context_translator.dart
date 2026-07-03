import '../models/translation.dart';
import 'text_context.dart';
import 'translation_service.dart';

/// Unique marker used to locate a span inside the HTML-translated sentence.
const String _markerTag = 'b';
final RegExp _markerRegex = RegExp(
  '<$_markerTag[^>]*>(.*?)</$_markerTag>',
  dotAll: true,
);

/// Translates a selection using the full sentence as context.
///
/// Strategy for partial selections:
///   1. Translate the **entire** sentence once (source of truth).
///   2. Map the selection to the corresponding words via proportional alignment.
///   3. If alignment fails, retry with a wider HTML-marked span around the
///      selection (neighbouring words inside `<b>`).
///   4. Fall back to translating the selection alone.
Future<TranslateResult> translateSelectionWithContext({
  required TranslationProvider provider,
  required String selection,
  required String contextSentence,
  required LocaleCode source,
  required LocaleCode target,
}) async {
  final displaySelection = selection.trim();
  final displaySentence = contextSentence.trim();
  final transSelection = normalizeForTranslation(displaySelection);
  final transSentence = normalizeForTranslation(displaySentence);

  if (transSentence.isEmpty || transSelection == transSentence) {
    return _result(
      await provider.translate(
        TranslateRequest(text: transSelection, source: source, target: target),
      ),
      displaySelection,
    );
  }

  if (!transSentence.contains(transSelection)) {
    return _result(
      await provider.translate(
        TranslateRequest(text: transSelection, source: source, target: target),
      ),
      displaySelection,
    );
  }

  final fromFull = await _translateViaFullSentence(
    provider: provider,
    sentence: transSentence,
    selection: transSelection,
    source: source,
    target: target,
  );
  if (fromFull != null) {
    return TranslateResult(
      translatedText: fromFull,
      source: source,
      target: target,
      originalText: displaySelection,
    );
  }

  final fromMark = await _translateAndExtract(
    provider: provider,
    sentence: transSentence,
    selection: transSelection,
    source: source,
    target: target,
  );
  if (fromMark != null &&
      fromMark.isNotEmpty &&
      !_isCaseInsensitiveEqual(fromMark, transSelection)) {
    return TranslateResult(
      translatedText: fromMark,
      source: source,
      target: target,
      originalText: displaySelection,
    );
  }

  return _result(
    await provider.translate(
      TranslateRequest(
        text: transSelection.toLowerCase(),
        source: source,
        target: target,
      ),
    ),
    displaySelection,
  );
}

/// Translates the full sentence and aligns the selection inside the result.
Future<String?> _translateViaFullSentence({
  required TranslationProvider provider,
  required String sentence,
  required String selection,
  required LocaleCode source,
  required LocaleCode target,
}) async {
  Future<String?> alignFrom(String translated) async {
    final aligned = alignSelectionInTranslation(
      sentence: sentence,
      selection: selection,
      translation: translated,
    );
    if (aligned == null || aligned.isEmpty) return null;
    if (_isCaseInsensitiveEqual(aligned, selection)) return null;
    return aligned;
  }

  final full = await provider.translate(
    TranslateRequest(text: sentence, source: source, target: target),
  );
  final aligned = await alignFrom(full.translatedText);
  if (aligned != null) return aligned;

  final loweredSelection = selection.toLowerCase();
  if (loweredSelection != selection) {
    final loweredSentence = _replaceFirst(sentence, selection, loweredSelection);
    final loweredFull = await provider.translate(
      TranslateRequest(
        text: loweredSentence,
        source: source,
        target: target,
      ),
    );
    return alignFrom(loweredFull.translatedText);
  }

  return null;
}

TranslateResult _result(TranslateResult api, String displayOriginal) {
  return TranslateResult(
    translatedText: api.translatedText,
    source: api.source,
    target: api.target,
    originalText: displayOriginal,
  );
}

Future<String?> _translateAndExtract({
  required TranslationProvider provider,
  required String sentence,
  required String selection,
  required LocaleCode source,
  required LocaleCode target,
}) async {
  final markSpan = buildMarkSpan(sentence, selection);
  final spanIndex = sentence.indexOf(markSpan.spanText);
  if (spanIndex < 0) return null;

  final before = _escapeHtml(sentence.substring(0, spanIndex));
  final middle = _escapeHtml(markSpan.spanText);
  final after = _escapeHtml(
    sentence.substring(spanIndex + markSpan.spanText.length),
  );
  final marked = '$before<$_markerTag>$middle</$_markerTag>$after';

  final result = await provider.translate(
    TranslateRequest(
      text: marked,
      source: source,
      target: target,
      format: TranslateFormat.html,
    ),
  );
  final markedInner = extractMarkedTranslation(result.translatedText);
  if (markedInner == null) return null;

  return extractSelectionFromMarkedSpan(markedInner, markSpan) ?? markedInner;
}

bool _isCaseInsensitiveEqual(String a, String b) {
  return a.toLowerCase() == b.toLowerCase();
}

String _replaceFirst(String haystack, String needle, String replacement) {
  final idx = haystack.indexOf(needle);
  if (idx < 0) return haystack;
  return haystack.substring(0, idx) +
      replacement +
      haystack.substring(idx + needle.length);
}

/// Returns the text inside the first `<b>...</b>` pair, or null if the
/// marker did not survive translation.
String? extractMarkedTranslation(String translatedHtml) {
  final match = _markerRegex.firstMatch(translatedHtml);
  if (match == null) return null;
  final inner = match.group(1);
  if (inner == null) return null;
  return _unescapeHtml(inner).trim();
}

String _escapeHtml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

String _unescapeHtml(String input) {
  return input
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');
}
