import 'package:book_reader/models/translation.dart';
import 'package:book_reader/services/context_translator.dart';
import 'package:book_reader/services/translation_service.dart';
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

  group('translateSelectionWithContext', () {
    test('sends html-marked sentence and extracts marker content', () async {
      final provider = _FakeProvider((req) async {
        expect(req.format, TranslateFormat.html);
        expect(req.text, contains('<b>bank</b>'));
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
      expect(provider.calls.length, 1);
    });

    test('falls back to translating the selection alone when marker is lost',
        () async {
      var callIndex = 0;
      final provider = _FakeProvider((req) async {
        callIndex++;
        if (callIndex == 1) {
          expect(req.format, TranslateFormat.html);
          return 'La orilla del río estaba fangosa.';
        }
        expect(req.format, TranslateFormat.text);
        expect(req.text, 'bank');
        return 'banco';
      });

      final result = await translateSelectionWithContext(
        provider: provider,
        selection: 'bank',
        contextSentence: 'The bank of the river was muddy.',
        source: 'en',
        target: 'es',
      );

      expect(result.translatedText, 'banco');
      expect(provider.calls.length, 2);
    });

    test('retries with lowercased selection when NMT keeps ALL CAPS verbatim',
        () async {
      var callIndex = 0;
      final provider = _FakeProvider((req) async {
        callIndex++;
        if (callIndex == 1) {
          expect(req.text, contains('<b>BIG</b>'));
          return 'Este es un <b>BIG</b> problema.';
        }
        expect(req.text, contains('<b>big</b>'));
        expect(req.text, isNot(contains('BIG')));
        return 'Este es un <b>gran</b> problema.';
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
  });
}
