import '../../data/datasources/local/word_list_asset.dart';

class GetSuggestions {
  final WordListAsset _asset;
  GetSuggestions({WordListAsset? asset}) : _asset = asset ?? WordListAsset();

  Future<List<String>> call(String prefix) => _asset.getSuggestions(prefix);
}
