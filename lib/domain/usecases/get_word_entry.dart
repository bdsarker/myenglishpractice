import '../../data/models/word_entry_model.dart';
import '../../data/repositories/word_repository.dart';

class GetWordEntry {
  final WordRepository _repository;
  GetWordEntry({WordRepository? repository}) : _repository = repository ?? WordRepository();

  Future<WordEntryModel> call(String word) => _repository.getWordEntry(word);
}
