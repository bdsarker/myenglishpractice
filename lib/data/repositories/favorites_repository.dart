import '../datasources/local/word_db.dart';
import '../models/word_entry_model.dart';

class FavoritesRepository {
  final WordDb _db;

  FavoritesRepository({WordDb? db}) : _db = db ?? WordDb();

  Future<void> saveFavorite(WordEntryModel entry) => _db.saveFavorite(entry);

  Future<void> removeFavorite(String word) => _db.removeFavorite(word);

  Future<bool> isFavorite(String word) => _db.isFavorite(word);

  Future<List<WordEntryModel>> getAllFavorites() async {
    final rows = await _db.getAllFavorites();
    return rows
        .map((row) => WordEntryModel(
              word: row['word'] as String,
              banglaDefinition: row['bangla_meaning'] as String?,
              isFavorite: true,
            ))
        .toList();
  }
}
