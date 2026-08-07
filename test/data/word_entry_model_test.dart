import 'package:flutter_test/flutter_test.dart';
import 'package:myenglishpractice/data/models/word_entry_model.dart';

void main() {
  group('hasContent', () {
    test('is true for a word the dictionary defines', () {
      expect(const WordEntryModel(word: 'apple').hasContent, isTrue);
    });

    test('is true when only example sentences survived', () {
      const entry = WordEntryModel(
        word: 'norwegian',
        found: false,
        sentences: ['Are you Norwegians?'],
      );

      expect(entry.hasContent, isTrue);
    });

    test('is true when only synonyms came back', () {
      const entry = WordEntryModel(
        word: 'yardmaster',
        found: false,
        synonyms: ['trainmaster'],
      );

      expect(entry.hasContent, isTrue);
    });

    test('is false when a Bangla string is the only thing on offer', () {
      // MyMemory transliterates whatever it is handed, so this alone proves
      // nothing about the word — "arrowsmith" comes back as "তীরচিহ্ন".
      const entry = WordEntryModel(
        word: 'arrowsmith',
        found: false,
        banglaDefinition: 'তীরচিহ্ন',
      );

      expect(entry.hasContent, isFalse);
    });

    test('is false when nothing at all came back', () {
      expect(
        const WordEntryModel(word: 'asdfgh', found: false).hasContent,
        isFalse,
      );
    });
  });
}
