import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/search_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _controller = TextEditingController();
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
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
    setState(() => _recentSearches = updated);
  }

  void _navigateToWord(String word) {
    _controller.clear();
    ref.read(searchProvider.notifier).clearSuggestions();
    _saveRecentSearch(word);
    context.push('/word/$word');
  }

  @override
  void dispose() {
    _controller.dispose();
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
              builder: (context, controller, focusNode) => TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  hintText: 'Type a word...',
                  prefixIcon: Icon(Icons.search, color: AppTheme.primary),
                ),
              ),
              suggestionsCallback: (pattern) async {
                ref.read(searchProvider.notifier).onQueryChanged(pattern);
                return ref.read(searchProvider).suggestions;
              },
              itemBuilder: (context, word) => ListTile(
                leading: const Icon(Icons.book_outlined, color: AppTheme.accent, size: 18),
                title: Text(word),
                dense: true,
              ),
              onSelected: _navigateToWord,
              emptyBuilder: (context) => const SizedBox.shrink(),
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
                      onTap: () => _navigateToWord(word),
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
