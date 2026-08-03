import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/word_list_asset.dart';
import '../../domain/usecases/get_suggestions.dart';

/// One instance per [ProviderScope] so the parsed word list is shared and the
/// asset is read only once.
final wordListAssetProvider = Provider<WordListAsset>((ref) => WordListAsset());

final getSuggestionsProvider = Provider<GetSuggestions>(
  (ref) => GetSuggestions(asset: ref.watch(wordListAssetProvider)),
);
