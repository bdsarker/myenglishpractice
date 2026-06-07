import '../../data/models/word_entry_model.dart';
import '../../data/repositories/favorites_repository.dart';

class GetAllFavorites {
  final FavoritesRepository _repository;
  GetAllFavorites({FavoritesRepository? repository}) : _repository = repository ?? FavoritesRepository();

  Future<List<WordEntryModel>> call() => _repository.getAllFavorites();
}
