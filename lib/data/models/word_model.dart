class WordModel {
  final String word;
  final String? phonetic;
  final String? partOfSpeech;
  final String? definition;

  const WordModel({
    required this.word,
    this.phonetic,
    this.partOfSpeech,
    this.definition,
  });

  factory WordModel.fromJson(Map<String, dynamic> json) => WordModel(
        word: json['word'] as String,
        phonetic: json['phonetic'] as String?,
        partOfSpeech: json['partOfSpeech'] as String?,
        definition: json['definition'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'word': word,
        'phonetic': phonetic,
        'partOfSpeech': partOfSpeech,
        'definition': definition,
      };

  WordModel copyWith({
    String? word,
    String? phonetic,
    String? partOfSpeech,
    String? definition,
  }) =>
      WordModel(
        word: word ?? this.word,
        phonetic: phonetic ?? this.phonetic,
        partOfSpeech: partOfSpeech ?? this.partOfSpeech,
        definition: definition ?? this.definition,
      );
}
