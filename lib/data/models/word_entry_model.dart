class WordEntryModel {
  final String word;
  final String? phonetic;
  final String? partOfSpeech;
  final String? englishDefinition;
  final String? banglaDefinition;
  final List<String> synonyms;
  final List<String> sentences;
  final bool isFavorite;

  const WordEntryModel({
    required this.word,
    this.phonetic,
    this.partOfSpeech,
    this.englishDefinition,
    this.banglaDefinition,
    this.synonyms = const [],
    this.sentences = const [],
    this.isFavorite = false,
  });

  factory WordEntryModel.fromJson(Map<String, dynamic> json) => WordEntryModel(
        word: json['word'] as String,
        phonetic: json['phonetic'] as String?,
        partOfSpeech: json['partOfSpeech'] as String?,
        englishDefinition: json['englishDefinition'] as String?,
        banglaDefinition: json['banglaDefinition'] as String?,
        synonyms: (json['synonyms'] as List<dynamic>?)?.cast<String>() ?? [],
        sentences: (json['sentences'] as List<dynamic>?)?.cast<String>() ?? [],
        isFavorite: json['isFavorite'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'word': word,
        'phonetic': phonetic,
        'partOfSpeech': partOfSpeech,
        'englishDefinition': englishDefinition,
        'banglaDefinition': banglaDefinition,
        'synonyms': synonyms,
        'sentences': sentences,
        'isFavorite': isFavorite,
      };

  WordEntryModel copyWith({
    String? word,
    String? phonetic,
    String? partOfSpeech,
    String? englishDefinition,
    String? banglaDefinition,
    List<String>? synonyms,
    List<String>? sentences,
    bool? isFavorite,
  }) =>
      WordEntryModel(
        word: word ?? this.word,
        phonetic: phonetic ?? this.phonetic,
        partOfSpeech: partOfSpeech ?? this.partOfSpeech,
        englishDefinition: englishDefinition ?? this.englishDefinition,
        banglaDefinition: banglaDefinition ?? this.banglaDefinition,
        synonyms: synonyms ?? this.synonyms,
        sentences: sentences ?? this.sentences,
        isFavorite: isFavorite ?? this.isFavorite,
      );
}
