import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/word_entry_model.dart';
import '../../domain/usecases/get_all_favorites.dart';
import '../../domain/usecases/toggle_favorite.dart';

class FavoritesNotifier extends StateNotifier<List<WordEntryModel>> {
  final GetAllFavorites _getAllFavorites;
  final ToggleFavorite _toggleFavorite;

  FavoritesNotifier(this._getAllFavorites, this._toggleFavorite) : super([]) {
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    state = await _getAllFavorites();
  }

  Future<bool> toggleFavorite(WordEntryModel entry) async {
    final isNowFavorite = await _toggleFavorite(entry);
    await loadFavorites();
    return isNowFavorite;
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<WordEntryModel>>((ref) {
  return FavoritesNotifier(GetAllFavorites(), ToggleFavorite());
});
