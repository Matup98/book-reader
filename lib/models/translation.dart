/// ISO 639-1 language code such as `en`, `es`, `fr`.
typedef LocaleCode = String;

class TranslateRequest {
  const TranslateRequest({
    required this.text,
    required this.source,
    required this.target,
    this.format = TranslateFormat.text,
  });

  final String text;
  final LocaleCode source;
  final LocaleCode target;
  final TranslateFormat format;
}

enum TranslateFormat {
  text,
  html;

  String get wireValue => name;
}

class TranslateResult {
  const TranslateResult({
    required this.translatedText,
    required this.source,
    required this.target,
    required this.originalText,
  });

  final String translatedText;
  final LocaleCode source;
  final LocaleCode target;
  final String originalText;
}

class TranslationException implements Exception {
  const TranslationException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'TranslationException: $message';
}
