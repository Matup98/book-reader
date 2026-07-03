import '../models/translation.dart';
import 'translation_service.dart';

/// Unique marker used to locate the selection inside the HTML-translated
/// sentence. Kept simple and short so the NMT engine is more likely to keep
/// it intact around the target word.
const String _markerTag = 'b';
final RegExp _markerRegex = RegExp(
  '<$_markerTag[^>]*>(.*?)</$_markerTag>',
  dotAll: true,
);

/// Translates a selection using the full sentence as context.
///
/// The strategy:
///   1. Wrap the [selection] with `<b>` markers inside [contextSentence].
///   2. Send the marked sentence to LibreTranslate with `format=html`.
///   3. Extract whatever ends up between `<b>` and `</b>` in the response.
///
/// The NMT model translates the whole sentence and normally moves the marker
/// with the target word, which lets us surface only the word's translation
/// to the user while still giving the engine full context.
///
/// If the marker is dropped by the model (rare but possible), or the
/// selection is not present verbatim in the sentence, we fall back to
/// translating [selection] alone.
Future<TranslateResult> translateSelectionWithContext({
  required TranslationProvider provider,
  required String selection,
  required String contextSentence,
  required LocaleCode source,
  required LocaleCode target,
}) async {
  final trimmedSentence = contextSentence.trim();
  final trimmedSelection = selection.trim();

  // If the whole sentence was selected, translate it directly.
  if (trimmedSentence.isEmpty || trimmedSelection == trimmedSentence) {
    return provider.translate(
      TranslateRequest(text: trimmedSelection, source: source, target: target),
    );
  }

  if (!trimmedSentence.contains(trimmedSelection)) {
    return provider.translate(
      TranslateRequest(text: trimmedSelection, source: source, target: target),
    );
  }

  final extracted = await _translateAndExtract(
    provider: provider,
    sentence: trimmedSentence,
    selection: trimmedSelection,
    source: source,
    target: target,
  );

  // NMT models (Argos/Marian) often preserve ALL-CAPS words verbatim because
  // they look like acronyms. When the extracted text is just a case-variant of
  // the source selection, we retry with a lowercased selection in the
  // sentence so the model treats it as a regular word.
  if (extracted != null &&
      extracted.isNotEmpty &&
      !_isCaseInsensitiveEqual(extracted, trimmedSelection)) {
    return TranslateResult(
      translatedText: extracted,
      source: source,
      target: target,
      originalText: trimmedSelection,
    );
  }

  final lowered = trimmedSelection.toLowerCase();
  if (lowered != trimmedSelection) {
    final loweredSentence = _replaceFirst(
      trimmedSentence,
      trimmedSelection,
      lowered,
    );
    final retry = await _translateAndExtract(
      provider: provider,
      sentence: loweredSentence,
      selection: lowered,
      source: source,
      target: target,
    );
    if (retry != null &&
        retry.isNotEmpty &&
        !_isCaseInsensitiveEqual(retry, lowered)) {
      return TranslateResult(
        translatedText: retry,
        source: source,
        target: target,
        originalText: trimmedSelection,
      );
    }
  }

  return provider.translate(
    TranslateRequest(
      text: lowered,
      source: source,
      target: target,
    ),
  );
}

Future<String?> _translateAndExtract({
  required TranslationProvider provider,
  required String sentence,
  required String selection,
  required LocaleCode source,
  required LocaleCode target,
}) async {
  final selIndex = sentence.indexOf(selection);
  if (selIndex < 0) return null;
  final before = _escapeHtml(sentence.substring(0, selIndex));
  final middle = _escapeHtml(selection);
  final after = _escapeHtml(sentence.substring(selIndex + selection.length));
  final marked = '$before<$_markerTag>$middle</$_markerTag>$after';

  final result = await provider.translate(
    TranslateRequest(
      text: marked,
      source: source,
      target: target,
      format: TranslateFormat.html,
    ),
  );
  return extractMarkedTranslation(result.translatedText);
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
