import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';

class WordListAsset {
  static final WordListAsset _instance = WordListAsset._();
  WordListAsset._();
  factory WordListAsset() => _instance;

  List<String>? _words;

  Future<List<String>> _loadWords() async {
    if (_words != null) return _words!;
    final raw = await rootBundle.loadString('assets/data/words.json');
    final list = jsonDecode(raw) as List<dynamic>;
    _words = list.cast<String>();
    return _words!;
  }

  Future<List<String>> getSuggestions(String prefix) async {
    if (prefix.isEmpty) return [];
    final words = await _loadWords();
    final lower = prefix.toLowerCase();
    return words
        .where((w) => w.toLowerCase().startsWith(lower))
        .take(AppConstants.suggestionLimit)
        .toList();
  }
}
