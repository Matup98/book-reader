import 'package:book_reader/models/translation.dart';
import 'package:book_reader/services/context_translator.dart';
import 'package:book_reader/services/translation_service.dart';
import 'package:book_reader/services/text_context.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProvider implements TranslationProvider {
  _FakeProvider(this.responder);

  final Future<String> Function(TranslateRequest) responder;
  final List<TranslateRequest> calls = [];

  @override
  Future<TranslateResult> translate(TranslateRequest request) async {
    calls.add(request);
    final translated = await responder(request);
    return TranslateResult(
      translatedText: translated,
      source: request.source,
      target: request.target,
      originalText: request.text,
    );
  }
}

void main() {
  group('extractMarkedTranslation', () {
    test('returns the marker contents', () {
      const html = 'El <b>gato</b> se sentó en la alfombra.';
      expect(extractMarkedTranslation(html), 'gato');
    });

    test('returns null when the marker is missing', () {
      expect(extractMarkedTranslation('El gato se sentó.'), isNull);
    });

    test('unescapes html entities', () {
      const html = 'a <b>tom &amp; jerry</b> b';
      expect(extractMarkedTranslation(html), 'tom & jerry');
    });
  });

  group('alignSelectionInTranslation', () {
    test('aligns gazed with the verb in the full sentence translation', () {
      const sentence =
          'the poster with the enormous face gazed from the wall';
      const fullEs =
          'el cartel con la enorme cara miraba desde la pared';

      expect(
        alignSelectionInTranslation(
          sentence: sentence,
          selection: 'gazed',
          translation: fullEs,
        ),
        'miraba',
      );
    });

    test('aligns bank with orilla in river context', () {
      const sentence = 'The bank of the river was muddy.';
      const fullEs = 'La orilla del río estaba fangosa.';

      expect(
        alignSelectionInTranslation(
          sentence: sentence,
          selection: 'bank',
          translation: fullEs,
        ),
        'orilla',
      );
    });
  });

  group('buildMarkSpan', () {
    test('includes neighbouring words around the selection', () {
      const sentence =
          'the poster with the enormous face gazed from the wall';
      final span = buildMarkSpan(sentence, 'gazed');
      expect(span.spanText, contains('face'));
      expect(span.spanText, contains('gazed'));
      expect(span.spanText, contains('from'));
      expect(span.selectionWordCount, 1);
    });
  });

  group('translateSelectionWithContext', () {
    test('uses full sentence translation and aligns the selection', () async {
      final provider = _FakeProvider((req) async {
        expect(req.format, TranslateFormat.text);
        expect(req.text, 'The bank of the river was muddy.');
        return 'La orilla del río estaba fangosa.';
      });

      final result = await translateSelectionWithContext(
        provider: provider,
        selection: 'bank',
        contextSentence: 'The bank of the river was muddy.',
        source: 'en',
        target: 'es',
      );

      expect(result.translatedText, 'orilla');
      expect(provider.calls.length, 1);
    });

    test('gazed matches the verb from the full sentence, not an isolated gloss',
        () async {
      final provider = _FakeProvider((req) async {
        return 'el cartel con la enorme cara miraba desde la pared';
      });

      final result = await translateSelectionWithContext(
        provider: provider,
        selection: 'gazed',
        contextSentence:
            'the poster with the enormous face gazed from the wall',
        source: 'en',
        target: 'es',
      );

      expect(result.translatedText, 'miraba');
      expect(provider.calls.length, 1);
    });

    test('falls back to marked span when alignment returns nothing', () async {
      var callIndex = 0;
      final provider = _FakeProvider((req) async {
        callIndex++;
        if (callIndex == 1) {
          expect(req.format, TranslateFormat.text);
          return '';
        }
        expect(req.format, TranslateFormat.html);
        return 'La <b>orilla</b> del río estaba fangosa.';
      });

      final result = await translateSelectionWithContext(
        provider: provider,
        selection: 'bank',
        contextSentence: 'The bank of the river was muddy.',
        source: 'en',
        target: 'es',
      );

      expect(result.translatedText, 'orilla');
      expect(provider.calls.length, 2);
    });

    test('retries with lowercased full sentence when alignment echoes source',
        () async {
      var callIndex = 0;
      final provider = _FakeProvider((req) async {
        callIndex++;
        if (callIndex == 1) {
          return 'Este es un BIG problema.';
        }
        return 'Este es un gran problema.';
      });

      final result = await translateSelectionWithContext(
        provider: provider,
        selection: 'BIG',
        contextSentence: 'This is a BIG problem.',
        source: 'en',
        target: 'es',
      );

      expect(result.translatedText, 'gran');
      expect(provider.calls.length, 2);
    });

    test('translates directly when selection equals the whole sentence',
        () async {
      final provider = _FakeProvider((req) async {
        expect(req.format, TranslateFormat.text);
        return 'Hola mundo.';
      });

      final result = await translateSelectionWithContext(
        provider: provider,
        selection: 'Hello world.',
        contextSentence: 'Hello world.',
        source: 'en',
        target: 'es',
      );

      expect(result.translatedText, 'Hola mundo.');
      expect(provider.calls.length, 1);
    });

    test('falls back when selection is not found in the sentence', () async {
      final provider = _FakeProvider((req) async {
        expect(req.format, TranslateFormat.text);
        expect(req.text, 'hello');
        return 'hola';
      });

      final result = await translateSelectionWithContext(
        provider: provider,
        selection: 'hello',
        contextSentence: 'Something entirely different.',
        source: 'en',
        target: 'es',
      );

      expect(result.translatedText, 'hola');
    });

    test('normalizes hyphens via full sentence alignment', () async {
      final provider = _FakeProvider((req) async {
        expect(req.text, contains('lift shaft'));
        return 'En cada rellano, frente al hueco del ascensor, el cartel.';
      });

      final result = await translateSelectionWithContext(
        provider: provider,
        selection: 'lift-shaft',
        contextSentence:
            'On each landing, opposite the lift-shaft, the poster...',
        source: 'en',
        target: 'es',
      );

      expect(result.translatedText, isNotEmpty);
      expect(result.originalText, 'lift-shaft');
    });
  });

  group('translateSelection', () {
    test('selectedText mode sends only the selection and returns full result',
        () async {
      final provider = _FakeProvider((req) async {
        expect(req.text, 'bank');
        expect(req.format, TranslateFormat.text);
        return 'banco';
      });

      final result = await translateSelection(
        provider: provider,
        mode: TranslationMode.selectedText,
        selection: 'bank',
        contextSentence: 'The bank of the river was muddy.',
        source: 'en',
        target: 'es',
      );

      expect(result.translatedText, 'banco');
      expect(result.originalText, 'bank');
      expect(provider.calls.length, 1);
    });

    test('selectedText mode never uses html format', () async {
      final provider = _FakeProvider((req) async => 'hola mundo');

      await translateSelection(
        provider: provider,
        mode: TranslationMode.selectedText,
        selection: 'hello world',
        contextSentence: 'She said hello world to everyone.',
        source: 'en',
        target: 'es',
      );

      expect(provider.calls.length, 1);
      expect(provider.calls.first.format, TranslateFormat.text);
    });

    test('selectedText mode normalizes hyphens in the selection', () async {
      final provider = _FakeProvider((req) async {
        expect(req.text, 'lift shaft');
        return 'hueco del ascensor';
      });

      final result = await translateSelection(
        provider: provider,
        mode: TranslationMode.selectedText,
        selection: 'lift-shaft',
        contextSentence: 'opposite the lift-shaft',
        source: 'en',
        target: 'es',
      );

      expect(result.translatedText, 'hueco del ascensor');
      expect(result.originalText, 'lift-shaft');
    });

    test('context mode uses the full sentence and aligns the selection',
        () async {
      final provider = _FakeProvider((req) async {
        expect(req.text, 'The bank of the river was muddy.');
        return 'La orilla del río estaba fangosa.';
      });

      final result = await translateSelection(
        provider: provider,
        mode: TranslationMode.context,
        selection: 'bank',
        contextSentence: 'The bank of the river was muddy.',
        source: 'en',
        target: 'es',
      );

      expect(result.translatedText, 'orilla');
    });

    test('NLLB engine skips the HTML fallback when alignment fails', () async {
      // First call returns an unusable translation for alignment; if the
      // engine were libretranslate we would then see a second call with
      // TranslateFormat.html. NLLB must go straight to the plain-text
      // fallback instead.
      final provider = _FakeProvider((req) async {
        expect(req.format, TranslateFormat.text);
        expect(req.engine, TranslationEngine.nllb);
        return 'orilla';
      });

      await translateSelection(
        provider: provider,
        mode: TranslationMode.context,
        engine: TranslationEngine.nllb,
        selection: 'bank',
        contextSentence: 'The bank of the river was muddy.',
        source: 'en',
        target: 'es',
      );

      for (final call in provider.calls) {
        expect(call.format, TranslateFormat.text);
        expect(call.engine, TranslationEngine.nllb);
      }
    });

    test('every request carries the selected engine', () async {
      final provider = _FakeProvider((req) async {
        expect(req.engine, TranslationEngine.nllb);
        return 'banco';
      });

      await translateSelection(
        provider: provider,
        mode: TranslationMode.selectedText,
        engine: TranslationEngine.nllb,
        selection: 'bank',
        contextSentence: 'The bank of the river was muddy.',
        source: 'en',
        target: 'es',
      );

      expect(provider.calls, isNotEmpty);
      expect(provider.calls.first.engine, TranslationEngine.nllb);
    });
  });
}
