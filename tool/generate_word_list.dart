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
//   1. Frequency ranking .. Norvig's count_1w.txt, the 333,333-entry unigram
//      list from the Google Trillion Word Corpus. Tab-separated "word<TAB>count",
//      already descending by count.
//   2. Keep /^[a-z]+$/ with length >= 3, plus an allowlist of real two-letter
//      words (the corpus also contains "aa", "ab", "af" and similar noise).
//   3. Intersect with dwyl/english-words words_alpha.txt (Unlicense) to drop
//      web-corpus junk such as http, www, php, jpg, url, aol, msn, isbn.
//   4. Drop LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words (CC-BY
//      4.0) plus a short denylist of web tokens that survive step 3.
//   5. Stop after [frequencyCutoff] survivors, then intersect with WordNet 3.1's
//      lemma index (Princeton, WordNet licence) — see below.
//
// Why two cuts rather than one:
//
// A suggested word has to lead somewhere. Roughly one in ten of the words that
// survive steps 1-4 has no dictionary entry, no synonyms and no example
// sentences anywhere — tapping it can only ever show an empty screen. Measured
// against the live APIs, those dead ends are overwhelmingly abbreviations (gld,
// dist, spp) and proper nouns (maris, findhorn, burberry), which occur at every
// frequency rank. A rank cap alone therefore does not help: cutting to the top
// 30,000 measured *worse* than keeping everything.
//
// WordNet is what removes that class, because it indexes lemmas rather than
// tokens. The two cuts together take the dead-end rate from ~11% to ~3%; either
// one alone lands around 9-14%.
//
// Frequency order still does the rest of the work: getSuggestions takes the
// first 10 prefix matches, so a rare word only surfaces when nothing more
// common shares its prefix.

import 'dart:convert';
import 'dart:io';

/// How far down the frequency ranking to look, counted *before* the WordNet
/// intersection so the cutoff means the same thing whatever WordNet contains.
const frequencyCutoff = 30000;

/// Sanity floor on the finished list. Falling under this means a source moved or
/// changed shape, which would silently gut the search box.
const minWordCount = 20000;
const outputPath = 'assets/data/words.json';

const frequencyUrl = 'https://www.norvig.com/ngrams/count_1w.txt';
const dictionaryUrl =
    'https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt';
const profanityUrl =
    'https://raw.githubusercontent.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words/master/en';

/// WordNet 3.1's four index files, which list one lemma per line.
///
/// Mirrored from the extjwnl data jar because Princeton ships WordNet only as a
/// tarball, and unpacking one would mean a new dependency for a tool that
/// otherwise needs nothing. Verified to reproduce the official lemma set
/// exactly: 86,589 single-word entries.
const wordnetUrls = [
  'https://raw.githubusercontent.com/extjwnl/extjwnl-data-wn31/master/src/main/resources/net/sf/extjwnl/data/wordnet/wn31/index.noun',
  'https://raw.githubusercontent.com/extjwnl/extjwnl-data-wn31/master/src/main/resources/net/sf/extjwnl/data/wordnet/wn31/index.verb',
  'https://raw.githubusercontent.com/extjwnl/extjwnl-data-wn31/master/src/main/resources/net/sf/extjwnl/data/wordnet/wn31/index.adj',
  'https://raw.githubusercontent.com/extjwnl/extjwnl-data-wn31/master/src/main/resources/net/sf/extjwnl/data/wordnet/wn31/index.adv',
];

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

final onlyLetters = RegExp(r'^[a-z]+$');

/// Every single-word lemma WordNet indexes, across all four parts of speech.
///
/// Each data line begins with the lemma, underscore-joined when it is a phrase
/// ("abandoned_infant") — the components are ordinary words, so they count too.
/// The licence header Princeton prepends to each file begins with a line number
/// rather than a lemma, so [onlyLetters] discards it without a special case.
Future<Set<String>> _fetchWordnetLemmas() async {
  final lemmas = <String>{};
  for (final url in wordnetUrls) {
    for (final line in await _fetchLines(url)) {
      for (final part in line.split(' ').first.split('_')) {
        if (onlyLetters.hasMatch(part)) lemmas.add(part);
      }
    }
  }
  stdout.writeln('  -> ${lemmas.length} WordNet lemmas');
  return lemmas;
}

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
  // "word<TAB>count" — _fetchLines trims the ends, so the count rides along on
  // each line and has to come off here.
  final frequency = (await _fetchLines(frequencyUrl))
      .map((line) => line.split('\t').first)
      .toList();
  final dictionary = (await _fetchLines(dictionaryUrl)).toSet();
  final profanity = (await _fetchLines(profanityUrl)).toSet();
  final wordnet = await _fetchWordnetLemmas();

  final seen = <String>{};
  final words = <String>[];
  var ranked = 0;

  for (final word in frequency) {
    if (!onlyLetters.hasMatch(word)) continue;
    if (word.length < 3 && !twoLetterAllowlist.contains(word)) continue;
    if (!dictionary.contains(word)) continue;
    if (profanity.contains(word) || webDenylist.contains(word)) continue;
    if (!seen.add(word)) continue;

    // Counted before the WordNet test, so the cutoff stays a statement about
    // frequency rank rather than shifting with WordNet's coverage.
    ranked++;
    if (ranked > frequencyCutoff) break;

    if (!wordnet.contains(word)) continue;
    words.add(word);
  }

  if (words.length < minWordCount) {
    stderr.writeln(
      'Warning: only ${words.length} words survived filtering '
      '(expected at least $minWordCount) — check the sources.',
    );
  }

  final file = File(outputPath);
  await file.writeAsString(jsonEncode(words));

  stdout.writeln('\nWrote ${words.length} words to $outputPath '
      '(${await file.length()} bytes)');
  stdout.writeln('Top 10: ${words.take(10).join(', ')}');
}
