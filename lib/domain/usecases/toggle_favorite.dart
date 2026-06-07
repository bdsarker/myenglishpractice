import '../../data/models/word_entry_model.dart';
import '../../data/repositories/favorites_repository.dart';

class ToggleFavorite {
  final FavoritesRepository _repository;
  ToggleFavorite({FavoritesRepository? repository}) : _repository = repository ?? FavoritesRepository();

  Future<bool> call(WordEntryModel entry) async {
    final current = await _repository.isFavorite(entry.word);
    if (current) {
      await _repository.removeFavorite(entry.word);
      return false;
    } else {
      await _repository.saveFavorite(entry);
      return true;
    }
  }
}
