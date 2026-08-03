import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/search_provider.dart';

/// Shortest query that gets the "Search for ..." fallback row. Below this,
/// a zero-match keystroke would flash an empty card on every character.
const _minCharsForSearchFallback = 3;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _suggestionsController = SuggestionsController<String>();
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    // Parse the word list now so the first keystroke doesn't wait on it.
    ref.read(wordListAssetProvider).load();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> _saveRecentSearch(String word) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = [word, ..._recentSearches.where((w) => w != word)]
        .take(AppConstants.recentSearchLimit)
        .toList();
    await prefs.setStringList('recent_searches', updated);
    if (!mounted) return;
    setState(() => _recentSearches = updated);
  }

  /// The single entry point for opening a word — used by suggestions, recent
  /// searches, the keyboard's Search key and the "Search for ..." row. The
  /// query is normalized here and nowhere else, so recent searches and the
  /// word cache never end up with both `Apple` and `apple`.
  void _go(String raw) {
    final word = raw.trim().toLowerCase();
    if (word.isEmpty) return;

    // Tear the overlay and keyboard down before pushing, otherwise both
    // animate away on top of the incoming route on iOS.
    _suggestionsController.close();
    _focusNode.unfocus();
    _controller.clear();

    _saveRecentSearch(word);
    context.push('/word/${Uri.encodeComponent(word)}');
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _suggestionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/favorites'),
        tooltip: 'Favorites',
        child: const Icon(Icons.favorite),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TypeAheadField<String>(
              controller: _controller,
              focusNode: _focusNode,
              suggestionsController: _suggestionsController,
              debounceDuration: const Duration(milliseconds: 120),
              constraints: const BoxConstraints(maxHeight: 280),
              builder: (context, controller, focusNode) => TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: _go,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  hintText: 'Type a word...',
                  prefixIcon: Icon(Icons.search, color: AppTheme.primary),
                ),
              ),
              suggestionsCallback: (pattern) =>
                  ref.read(getSuggestionsProvider)(pattern),
              itemBuilder: (context, word) => ListTile(
                leading: const Icon(Icons.book_outlined, color: AppTheme.accent, size: 18),
                title: Text(word),
                dense: true,
              ),
              onSelected: _go,
              loadingBuilder: (context) => const SizedBox.shrink(),
              emptyBuilder: (context) => ValueListenableBuilder(
                // emptyBuilder gets no pattern, and it only reruns when the
                // suggestions change — so read the query from the controller.
                valueListenable: _controller,
                builder: (context, value, _) {
                  final query = value.text.trim();
                  if (query.length < _minCharsForSearchFallback) {
                    return const SizedBox.shrink();
                  }
                  return ListTile(
                    leading: const Icon(Icons.search, color: AppTheme.primary, size: 18),
                    title: Text('Search for "$query"'),
                    dense: true,
                    onTap: () => _go(query),
                  );
                },
              ),
              decorationBuilder: (context, child) => Material(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                elevation: 4,
                child: child,
              ),
            ),
            const SizedBox(height: 24),
            if (_recentSearches.isNotEmpty) ...[
              Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _recentSearches.length,
                  itemBuilder: (context, index) {
                    final word = _recentSearches[index];
                    return ListTile(
                      leading: const Icon(Icons.history, color: Colors.white38, size: 18),
                      title: Text(word),
                      onTap: () => _go(word),
                    )
                        .animate(delay: Duration(milliseconds: index * 50))
                        .fadeIn()
                        .slideX(begin: -0.1, end: 0);
                  },
                ),
              ),
            ] else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_rounded, size: 64, color: AppTheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Type a word to get started',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ).animate().fadeIn(duration: 600.ms),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
