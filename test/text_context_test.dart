import 'package:flutter_test/flutter_test.dart';
import 'package:book_reader/services/text_context.dart';

void main() {
  group('normalizeForTranslation', () {
    test('splits hyphenated compounds into separate tokens', () {
      expect(normalizeForTranslation('lift-shaft'), 'lift shaft');
      expect(
        normalizeForTranslation('opposite the lift-shaft'),
        'opposite the lift shaft',
      );
    });

    test('does not split hyphens at word boundaries', () {
      expect(normalizeForTranslation('-start'), '-start');
      expect(normalizeForTranslation('end-'), 'end-');
    });
  });

  group('normalizeText', () {
    test('collapses line breaks inside a selection', () {
      expect(normalizeText('On\neach landing'), 'On each landing');
    });

    test('collapses multiple whitespace characters', () {
      expect(normalizeText('On  \n  each   landing'), 'On each landing');
    });
  });

  group('expandToSentence', () {
    test('expands a single word to its containing sentence', () {
      const page =
          'The quick brown fox jumps over the lazy dog. '
          'Another sentence follows here.';
      expect(
        expandToSentence('brown', page),
        'The quick brown fox jumps over the lazy dog.',
      );
    });

    test('handles line breaks from PDF extraction', () {
      const page =
          'The quick brown\nfox jumps over the lazy\n   dog. Another one.';
      expect(
        expandToSentence('brown fox', page),
        'The quick brown fox jumps over the lazy dog.',
      );
    });

    test('returns whole page text when no terminator is found', () {
      const page = 'A page without terminators just a phrase';
      expect(expandToSentence('phrase', page), page);
    });

    test('returns normalized selection when selection is not in the page', () {
      const page = 'Some unrelated text.';
      expect(expandToSentence('missing', page), 'missing');
    });

    test('handles question marks and exclamations', () {
      const page = 'Really? Yes! It works. Try again.';
      expect(expandToSentence('Yes', page), 'Yes!');
    });
  });

  group('expandToParagraph', () {
    test('returns the paragraph containing the selection', () {
      const page =
          'First paragraph line one.\nFirst paragraph line two.\n\n'
          'Second paragraph with the target word.\n\n'
          'Third paragraph unrelated.';
      expect(
        expandToParagraph('target', page),
        'Second paragraph with the target word.',
      );
    });
  });
}
