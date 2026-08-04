class AppConstants {
  static const String appName = 'Word Depot';
  static const int suggestionLimit = 10;
  static const int synonymLimit = 5;

  /// Example sentences shown at once. The rest of the pool sits behind shuffle.
  static const int sentenceLimit = 5;

  /// How many sentences to fetch and cache, so shuffling costs no network.
  static const int sentencePoolLimit = 12;
  static const int recentSearchLimit = 10;
  static const int cacheDurationHours = 24;
}
