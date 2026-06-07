import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final filtered = _filter.isEmpty
        ? favorites
        : favorites
            .where((f) => f.word.toLowerCase().contains(_filter.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Words')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Filter saved words...',
                prefixIcon: Icon(Icons.search, color: AppTheme.primary),
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_outline_rounded,
                            size: 64, color: Colors.white12),
                        const SizedBox(height: 16),
                        Text(
                          'No saved words yet',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white38),
                        ),
                      ],
                    ).animate().fadeIn(),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(entry.word,
                              style: Theme.of(context).textTheme.bodyLarge),
                          subtitle: entry.banglaDefinition != null
                              ? Text(
                                  entry.banglaDefinition!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.white38),
                                )
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 20),
                            onPressed: () => ref
                                .read(favoritesProvider.notifier)
                                .toggleFavorite(entry),
                          ),
                          onTap: () => context.push('/word/${entry.word}'),
                        ),
                      )
                          .animate(delay: Duration(milliseconds: index * 40))
                          .fadeIn()
                          .slideX(begin: 0.05, end: 0);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
