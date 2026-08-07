import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/word_entry_model.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/speech_provider.dart';
import '../../providers/word_detail_provider.dart';
import 'shimmer_word_detail.dart';

/// Stateful only so [dispose] can silence the engine — otherwise tapping back
/// mid-sentence leaves the phone talking to itself.
class WordDetailScreen extends ConsumerStatefulWidget {
  final String word;
  const WordDetailScreen({super.key, required this.word});

  @override
  ConsumerState<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends ConsumerState<WordDetailScreen> {
  String get word => widget.word;

  /// Held rather than read in [dispose]: `ref` is already invalidated by then.
  /// Safe to hold because the notifier lives in the root scope, for the life of
  /// the app.
  late final SpeechNotifier _speech;

  @override
  void initState() {
    super.initState();
    _speech = ref.read(speechProvider.notifier);
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncEntry = ref.watch(wordDetailProvider(word));
    // Only once there is something to favourite: absent while loading, and for
    // a word the dictionary has no entry for.
    final entry = asyncEntry.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(word),
        actions: [
          if (entry != null && entry.hasContent) _FavoriteButton(entry: entry),
        ],
      ),
      body: asyncEntry.when(
        loading: () => const ShimmerWordDetail(),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
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
        data: (entry) => entry.hasContent
            ? _WordDetailBody(entry: entry)
            : _WordNotFound(word: entry.word),
      ),
    );
  }
}

/// Explains a body with no definition in it.
///
/// The dictionary has no entry for plenty of ordinary words — `norwegian` and
/// `bangkok` among them — while the corpus covers them fine. Deliberately not
/// styled as an error: nothing failed, and a retry would change nothing.
class _PartialResultsNotice extends StatelessWidget {
  const _PartialResultsNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 18, color: AppTheme.inkFaint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No dictionary definition for this word. '
                'Here is what we could find.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.inkFaint),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

/// Shown only when no source returned anything at all — no definition, no
/// synonyms, no example sentences.
///
/// Reachable by tapping one of our own suggestions, not just by mistyping, so
/// the copy leads with the dictionary's gap rather than blaming the spelling.
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
            const Icon(Icons.search_off_rounded, size: 64, color: AppTheme.inkFaint),
            const SizedBox(height: 16),
            Text(
              'Nothing found for "$word"',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This word is not in our dictionary, and no example '
              'sentences turned up for it either.',
              style: textTheme.bodyMedium?.copyWith(color: AppTheme.inkFaint),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'If you typed it yourself, check the spelling.',
              style: textTheme.bodySmall?.copyWith(color: AppTheme.inkFaint),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Says up front why the definition is missing, so the gap reads as a
          // known limit of the dictionary rather than a half-loaded screen.
          if (!entry.found) ...[
            const _PartialResultsNotice(),
            const SizedBox(height: 16),
          ],

          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                // Wrap, not Row: a long word plus both tags overflows a narrow
                // phone, and the tags should drop to the next line rather than
                // clip. Wrap hands its children unbounded width though, so each
                // one is capped explicitly or a long word or IPA still spills.
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    ConstrainedBox capped(Widget child) => ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: constraints.maxWidth),
                          child: child,
                        );

                    return Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        capped(Text(entry.word, style: textTheme.titleLarge)),
                        if (entry.phonetic != null)
                          capped(_Tag(label: entry.phonetic!)),
                        if (entry.partOfSpeech != null)
                          capped(_Tag(label: entry.partOfSpeech!)),
                      ],
                    );
                  },
                ),
              ),
              _SpeakButton(
                text: entry.word,
                size: 28,
                tooltip: 'Pronounce "${entry.word}"',
              ),
            ],
          ).animate().fadeIn().slideY(begin: -0.05, end: 0),

          // Synonyms
          if (entry.synonyms.isNotEmpty) ...[
            // Matches the gap below the label, so it groups with the chips it
            // describes rather than floating between two sections.
            const SizedBox(height: 8),
            Text('Synonyms',
                style: textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.inkFaint, fontSize: 12)),
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
                            ?.copyWith(color: AppTheme.inkFaint, fontSize: 12)),
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
          if (entry.sentences.isNotEmpty)
            _ExampleSentences(sentences: entry.sentences),
        ],
      ),
    );
  }
}

/// Reads [text] aloud, or stops it if this is the text already playing.
///
/// Only one thing speaks at a time app-wide, so every instance watches the same
/// [speechProvider] and at most one of them shows a stop icon.
class _SpeakButton extends ConsumerWidget {
  final String text;
  final double size;
  final String tooltip;

  const _SpeakButton({
    required this.text,
    required this.size,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSpeaking = ref.watch(speechProvider) == text;

    return IconButton(
      icon: Icon(
        isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
        color: AppTheme.primary,
        size: size,
      ),
      tooltip: isSpeaking ? 'Stop' : tooltip,
      // Keeps the sentence rows' leading slot near 40px instead of pushing the
      // text right by a full 48px button.
      visualDensity: VisualDensity.compact,
      onPressed: () => ref.read(speechProvider.notifier).toggle(text),
    );
  }
}

/// The favourite star, in the AppBar so the word and its pills get the whole
/// width of the row below.
class _FavoriteButton extends ConsumerWidget {
  final WordEntryModel entry;
  const _FavoriteButton({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final isFav = favorites.any((f) => f.word == entry.word) || entry.isFavorite;

    return IconButton(
      icon: Icon(
        isFav ? Icons.star_rounded : Icons.star_outline_rounded,
        color: isFav ? AppTheme.accent : AppTheme.inkFaint,
        size: 28,
      ),
      tooltip: isFav ? 'Remove from saved words' : 'Save this word',
      onPressed: () =>
          ref.read(favoritesProvider.notifier).toggleFavorite(entry),
    );
  }
}

/// The pronunciation and part-of-speech pills that sit beside the word.
///
/// A true oval: [StadiumBorder] rather than the theme's rounded rectangle, so
/// the ends stay semicircular whatever the label's length.
class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: ShapeDecoration(
        color: AppTheme.primary.withAlpha(40),
        shape: StadiumBorder(
          side: BorderSide(color: AppTheme.primary.withAlpha(90)),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              // Solid, not the alpha-230 the dark backdrop wanted — over the
              // pale teal fill this is what keeps the label at full contrast.
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Shows [AppConstants.sentenceLimit] of the cached pool, with a shuffle button
/// for the rest.
///
/// The draw happens in [initState], never in `build` — otherwise any unrelated
/// rebuild (favouriting the word, say) would reshuffle under the user's finger.
class _ExampleSentences extends StatefulWidget {
  final List<String> sentences;
  const _ExampleSentences({required this.sentences});

  @override
  State<_ExampleSentences> createState() => _ExampleSentencesState();
}

class _ExampleSentencesState extends State<_ExampleSentences> {
  late List<String> _shown;

  bool get _canShuffle => widget.sentences.length > AppConstants.sentenceLimit;

  @override
  void initState() {
    super.initState();
    _shown = _draw();
  }

  @override
  void didUpdateWidget(_ExampleSentences oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sentences != oldWidget.sentences) {
      _shown = _draw();
    }
  }

  List<String> _draw() => (List<String>.of(widget.sentences)..shuffle())
      .take(AppConstants.sentenceLimit)
      .toList();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.format_quote_rounded, color: AppTheme.primary, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Example Sentences',
                  style: textTheme.titleMedium?.copyWith(fontSize: 14)),
            ),
            if (_canShuffle)
              IconButton(
                icon: const Icon(Icons.shuffle_rounded,
                    size: 18, color: AppTheme.primary),
                tooltip: 'Show different sentences',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _shown = _draw()),
              ),
          ],
        ),
        const Divider(height: 16),
        ..._shown.asMap().entries.map((e) {
          return Card(
            // Keyed by text so a shuffle replays the entry animation instead of
            // swapping the string inside the old element.
            key: ValueKey(e.value),
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: _SpeakButton(
                text: e.value,
                size: 20,
                tooltip: 'Read this sentence',
              ),
              title: Text(e.value, style: textTheme.bodyMedium),
              trailing: Builder(builder: (ctx) {
                return IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: AppTheme.inkFaint),
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
        // Tatoeba sentences are CC BY 2.0 FR — the credit is a licence term.
        const SizedBox(height: 4),
        Text(
          'Examples from Tatoeba · CC BY 2.0 FR',
          style: textTheme.bodySmall?.copyWith(color: AppTheme.decor, fontSize: 11),
        ),
      ],
    );
  }
}
