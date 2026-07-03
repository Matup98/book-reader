/// ISO 639-1 language code such as `en`, `es`, `fr`.
typedef LocaleCode = String;

/// Backend translation engine. All engines are reached through the local
/// proxy; the wire value is what the proxy expects in the `engine` field.
enum TranslationEngine {
  libretranslate,
  nllb;
  // Future: deepl.

  /// LibreTranslate accepts an HTML marker; NLLB (and future cloud engines)
  /// only translate plain text.
  bool get supportsHtmlMarkers => this == TranslationEngine.libretranslate;

  String get wireValue => name;

  static TranslationEngine fromWireValue(String? value) {
    for (final engine in TranslationEngine.values) {
      if (engine.wireValue == value) return engine;
    }
    return TranslationEngine.libretranslate;
  }
}

class TranslateRequest {
  const TranslateRequest({
    required this.text,
    required this.source,
    required this.target,
    this.format = TranslateFormat.text,
    this.engine = TranslationEngine.libretranslate,
  });

  final String text;
  final LocaleCode source;
  final LocaleCode target;
  final TranslateFormat format;
  final TranslationEngine engine;
}

enum TranslateFormat {
  text,
  html;

  String get wireValue => name;
}

/// How the user's selection is translated in the reader.
enum TranslationMode {
  /// Full sentence is sent as context; overlay shows only the aligned span.
  context,

  /// Only the highlighted text is sent; overlay shows its literal translation.
  selectedText;

  String get wireValue => name;

  static TranslationMode fromWireValue(String? value) {
    for (final mode in TranslationMode.values) {
      if (mode.wireValue == value) return mode;
    }
    return TranslationMode.context;
  }
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
