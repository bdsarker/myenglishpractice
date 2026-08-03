import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';

/// Prefix lookup over the bundled word list.
///
/// `assets/data/words.json` is ordered by descending frequency, so taking the
/// first N prefix matches yields the most commonly used words first. See
/// `tool/generate_word_list.dart`.
class WordListAsset {
  WordListAsset({Future<String> Function(String key)? loader})
      : _loader = loader ?? rootBundle.loadString;

  static const assetKey = 'assets/data/words.json';

  final Future<String> Function(String key) _loader;

  /// Frequency-ordered and de-duplicated.
  List<String> _words = const [];
  Set<String> _wordSet = const {};
  Future<void>? _loading;

  /// Reads and parses the asset once. Safe to call concurrently; a failed load
  /// is not cached, so a later call retries.
  Future<void> load() {
    return _loading ??= _read().catchError((Object error, StackTrace stack) {
      _loading = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _read() async {
    final raw = await _loader(assetKey);
    final list = (jsonDecode(raw) as List<dynamic>).cast<String>();

    final seen = <String>{};
    final words = <String>[];
    for (final word in list) {
      final normalized = word.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      if (!seen.add(normalized)) continue;
      words.add(normalized);
    }

    _words = words;
    _wordSet = seen;
  }

  /// Words starting with [prefix], most common first, capped at
  /// [AppConstants.suggestionLimit]. An exact match is always shown first.
  Future<List<String>> getSuggestions(String prefix) async {
    final query = prefix.trim().toLowerCase();
    if (query.isEmpty) return const [];

    await load();

    // The words are already lowercase, so `startsWith` needs no per-word
    // allocation and `take` short-circuits once the limit is reached.
    final matches = _words
        .where((word) => word.startsWith(query))
        .take(AppConstants.suggestionLimit)
        .toList();

    // An exact match can rank below the limit, so promote it by membership
    // rather than by reordering what `take` happened to return.
    if (_wordSet.contains(query)) {
      matches.remove(query);
      matches.insert(0, query);
      if (matches.length > AppConstants.suggestionLimit) {
        matches.removeLast();
      }
    }

    return matches;
  }
}
