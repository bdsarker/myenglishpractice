import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/word_entry_model.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/word_detail_provider.dart';
import 'shimmer_word_detail.dart';

class WordDetailScreen extends ConsumerWidget {
  final String word;
  const WordDetailScreen({super.key, required this.word});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntry = ref.watch(wordDetailProvider(word));

    return Scaffold(
      appBar: AppBar(title: Text(word)),
      body: asyncEntry.when(
        loading: () => const ShimmerWordDetail(),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 12),
                Text(e.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(wordDetailProvider(word)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (entry) => entry.found
            ? _WordDetailBody(entry: entry)
            : _WordNotFound(word: entry.word),
      ),
    );
  }
}

/// Shown when the dictionary has no entry for the word — usually a typo, since
/// the search box now opens whatever the user typed.
class _WordNotFound extends StatelessWidget {
  final String word;
  const _WordNotFound({required this.word});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              'No definition found for "$word"',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check the spelling and try again.',
              style: textTheme.bodyMedium?.copyWith(color: Colors.white38),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to search'),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms),
      ),
    );
  }
}

class _WordDetailBody extends ConsumerWidget {
  final WordEntryModel entry;
  const _WordDetailBody({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final favorites = ref.watch(favoritesProvider);
    final isFav = favorites.any((f) => f.word == entry.word) || entry.isFavorite;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.word, style: textTheme.titleLarge),
                    if (entry.phonetic != null)
                      Text(entry.phonetic!,
                          style: textTheme.bodyMedium?.copyWith(color: AppTheme.primary)),
                    if (entry.partOfSpeech != null)
                      Chip(
                        label: Text(entry.partOfSpeech!),
                        backgroundColor: AppTheme.primary.withAlpha(40),
                        labelStyle: TextStyle(
                            color: AppTheme.primary.withAlpha(220), fontSize: 12),
                        side: BorderSide(color: AppTheme.primary.withAlpha(100)),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFav ? AppTheme.accent : Colors.white38,
                  size: 32,
                ),
                onPressed: () =>
                    ref.read(favoritesProvider.notifier).toggleFavorite(entry),
              ),
            ],
          ).animate().fadeIn().slideY(begin: -0.05, end: 0),

          // Synonyms
          if (entry.synonyms.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Synonyms',
                style: textTheme.bodyMedium
                    ?.copyWith(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: entry.synonyms.asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(label: Text(e.value))
                        .animate(delay: Duration(milliseconds: e.key * 80))
                        .fadeIn()
                        .scale(begin: const Offset(0.8, 0.8)),
                  );
                }).toList(),
              ),
            ),
          ],

          // Combined meanings card
          if (entry.banglaDefinition != null || entry.englishDefinition != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Meanings',
                        style: textTheme.bodyMedium
                            ?.copyWith(color: Colors.white38, fontSize: 12)),
                    const Divider(height: 16),
                    if (entry.banglaDefinition != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🇧🇩', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Bangla',
                                    style: textTheme.bodyMedium?.copyWith(
                                        color: AppTheme.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(entry.banglaDefinition!,
                                    style: textTheme.bodyLarge),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (entry.englishDefinition != null)
                        const Divider(height: 20),
                    ],
                    if (entry.englishDefinition != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🔤', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('English',
                                    style: textTheme.bodyMedium?.copyWith(
                                        color: AppTheme.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(entry.englishDefinition!,
                                    style: textTheme.bodyLarge),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 100.ms),
          ],

          // Example sentences
          if (entry.sentences.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.format_quote_rounded, color: AppTheme.primary, size: 18),
                const SizedBox(width: 6),
                Text('Example Sentences',
                    style: textTheme.titleMedium?.copyWith(fontSize: 14)),
              ],
            ),
            const Divider(height: 16),
            ...entry.sentences.asMap().entries.map((e) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.book_outlined,
                      color: AppTheme.primary, size: 20),
                  title: Text(e.value, style: textTheme.bodyMedium),
                  trailing: Builder(builder: (ctx) {
                    return IconButton(
                      icon: const Icon(Icons.copy, size: 16, color: Colors.white38),
                      tooltip: 'Copy',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: e.value));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Sentence copied!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    );
                  }),
                ),
              )
                  .animate(delay: Duration(milliseconds: 200 + e.key * 60))
                  .fadeIn()
                  .slideY(begin: 0.05, end: 0);
            }),
          ],
        ],
      ),
    );
  }
}
