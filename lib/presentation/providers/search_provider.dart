import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/get_suggestions.dart';

class SearchState {
  final String query;
  final List<String> suggestions;

  const SearchState({this.query = '', this.suggestions = const []});

  SearchState copyWith({String? query, List<String>? suggestions}) =>
      SearchState(
        query: query ?? this.query,
        suggestions: suggestions ?? this.suggestions,
      );
}

class SearchNotifier extends StateNotifier<SearchState> {
  final GetSuggestions _getSuggestions;
  Timer? _debounce;

  SearchNotifier(this._getSuggestions) : super(const SearchState());

  void onQueryChanged(String query) {
    _debounce?.cancel();
    state = state.copyWith(query: query);
    if (query.isEmpty) {
      state = state.copyWith(suggestions: []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final suggestions = await _getSuggestions(query);
      state = state.copyWith(suggestions: suggestions);
    });
  }

  void clearSuggestions() {
    _debounce?.cancel();
    state = const SearchState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(GetSuggestions());
});
