// Regenerates assets/data/words.json — the suggestion list behind the search box.
//
//   dart run tool/generate_word_list.dart
//
// The output is a flat JSON array of lowercase words in DESCENDING FREQUENCY
// order. That ordering is load-bearing: WordListAsset.getSuggestions filters by
// prefix and takes the first N, so file order *is* the ranking. Do not sort the
// asset alphabetically — test/data/word_list_asset_test.dart asserts the order.
//
// Pipeline:
//   1. Frequency ranking .. first20hours/google-10000-english 20k.txt (MIT),
//      derived from the Google Trillion Word Corpus.
//   2. Keep /^[a-z]+$/ with length >= 3, plus an allowlist of real two-letter
//      words (the corpus also contains "aa", "ab", "af" and similar noise).
//   3. Intersect with dwyl/english-words words_alpha.txt (Unlicense) to drop
//      web-corpus junk such as http, www, php, jpg, url, aol, msn, isbn.
//   4. Drop LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words (CC-BY
//      4.0) plus a short denylist of web tokens that survive step 3.
//   5. Dedupe preserving order, take the first [wordCount].

import 'dart:convert';
import 'dart:io';

const wordCount = 10000;
const outputPath = 'assets/data/words.json';

const frequencyUrl =
    'https://raw.githubusercontent.com/first20hours/google-10000-english/master/20k.txt';
const dictionaryUrl =
    'https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt';
const profanityUrl =
    'https://raw.githubusercontent.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words/master/en';

/// Two-letter words worth suggesting. Anything shorter than three characters
/// that is not in here is corpus noise.
const twoLetterAllowlist = {
  'am', 'an', 'as', 'at', 'be', 'by', 'do', 'go', 'he', 'hi', 'if', 'in', //
  'is', 'it', 'me', 'my', 'no', 'of', 'oh', 'ok', 'on', 'or', 'so', 'to', //
  'up', 'us', 'we',
};

/// Web/file-format tokens that words_alpha happens to contain.
const webDenylist = {
  'com', 'net', 'org', 'inc', 'ltd', 'faq', 'asp', 'pdf', 'gif', 'png', //
  'exe', 'dvd', 'mpeg', 'mysql', 'linux', 'cgi', 'sql',
};

Future<List<String>> _fetchLines(String url) async {
  stdout.write('  $url ... ');
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
    }
    final body = await response.transform(utf8.decoder).join();
    final lines = const LineSplitter()
        .convert(body)
        .map((l) => l.trim().toLowerCase())
        .where((l) => l.isNotEmpty)
        .toList();
    stdout.writeln('${lines.length} lines');
    return lines;
  } finally {
    client.close();
  }
}

Future<void> main() async {
  stdout.writeln('Downloading sources:');
  final frequency = await _fetchLines(frequencyUrl);
  final dictionary = (await _fetchLines(dictionaryUrl)).toSet();
  final profanity = (await _fetchLines(profanityUrl)).toSet();

  final onlyLetters = RegExp(r'^[a-z]+$');
  final seen = <String>{};
  final words = <String>[];

  for (final word in frequency) {
    if (!onlyLetters.hasMatch(word)) continue;
    if (word.length < 3 && !twoLetterAllowlist.contains(word)) continue;
    if (!dictionary.contains(word)) continue;
    if (profanity.contains(word) || webDenylist.contains(word)) continue;
    if (!seen.add(word)) continue;
    words.add(word);
    if (words.length == wordCount) break;
  }

  if (words.length < wordCount) {
    stderr.writeln(
      'Warning: only ${words.length} words survived filtering '
      '(wanted $wordCount).',
    );
  }

  final file = File(outputPath);
  await file.writeAsString(jsonEncode(words));

  stdout.writeln('\nWrote ${words.length} words to $outputPath '
      '(${await file.length()} bytes)');
  stdout.writeln('Top 10: ${words.take(10).join(', ')}');
}
