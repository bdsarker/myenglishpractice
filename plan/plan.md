## Plan Summary
I want to develop an mobile application to practice English sentence with words. 
- For example, if I write a word, it will suggest 5 or 10 simple sentences to better understand the words. 
- Also, at the typing to the text box will suggest the most useful words. Suppose if I type ad it will suggest the words start with ad. 
- Also it will tell me about the meaning in Bangla of the word after selecting a word. 
- Also 5 synonyms will be displayed at the top. 
- I want to save the words as my favorite.
- Find the details architecture below for plan


## 📋 Development Phases & CLI Commands

---

### Phase 1 — Project Structure & Core Setup

```bash
# Inside project dir, start claude code
claude

# Prompt 1: Scaffold architecture
> Create the full folder structure for a Flutter app called EnglishBuddy following clean architecture with layers: data, domain, presentation. Include core/constants, core/theme, `core/utils folders. Create empty placeholder dart files in each folder with correct naming conventions.

# Prompt 2: Setup dependencies
> Update pubspec.yaml to add these dependencies: dio, riverpod, flutter_riverpod, sqflite, path_provider, flutter_typeahead, flutter_animate, english_words. Also add a local asset folder assets/data/ and register it.

# Run after
flutter pub get
```

---

### Phase 2 — Word Data & Assets

```bash
# Prompt 3: Generate word list asset
> Create a JSON file at assets/data/words.json containing 500 common English words as a simple array of strings sorted alphabetically. Words should be useful for everyday English learning.

# Prompt 4: Word asset loader
> Create lib/data/datasources/local/word_list_asset.dart that loads words.json from assets using rootBundle, parses it as List<String>, and exposes a method getSuggestions(String prefix) that returns up to 10 words starting with that prefix. Make it a singleton with lazy initialization.
```

---

### Phase 3 — API Integrations

```bash
# Prompt 5: Dictionary API
> Create lib/data/datasources/remote/dictionary_api.dart using dio to call https://api.dictionaryapi.dev/api/v2/entries/en/{word}. Parse the response and return the first definition, part of speech, and phonetic text. Handle 404 and network errors gracefully by returning null.

# Prompt 6: Datamuse synonyms
> Create lib/data/datasources/remote/datamuse_api.dart that calls https://api.datamuse.com/words?rel_syn={word}&max=5 using dio. Return a List<String> of synonym words. Handle empty responses and errors gracefully.

# Prompt 7: Translation API
> Create lib/data/datasources/remote/translate_api.dart that calls LibreTranslate API at https://libretranslate.com/translate with POST body: source=en, target=bn, q={text}. Parse the translatedText field from response. Add error handling that returns empty string on failure.

# Prompt 8: Wordnik sentences
> Create lib/data/datasources/remote/wordnik_api.dart with my API key stored in core/constants/api_keys.dart. Call https://api.wordnik.com/v4/word.json/{word}/examples?limit=7&api_key={key}. Parse and return List<String> of example sentences. If API fails return 3 hardcoded fallback sentences containing the word.
```

---

### Phase 4 — Models & Repository

```bash
# Prompt 9: Data models
> Create these data models in lib/data/models/:
> - word_model.dart with fields: word(String), phonetic(String?), partOfSpeech(String?), definition(String?)
> - word_entry_model.dart with fields: word, phonetic, partOfSpeech, englishDefinition, banglaDefinition, synonyms(List<String>), sentences(List<String>), isFavorite(bool)
> Add fromJson/toJson and copyWith methods to each.

# Prompt 10: SQLite database
> Create lib/data/datasources/local/word_db.dart using sqflite. Implement two tables: favorites(id, word, bangla_meaning, saved_at) and word_cache(word, synonyms_json, sentences_json, bangla_meaning, cached_at). Add methods: saveFavorite, removeFavorite, getAllFavorites, isFavorite, cacheWord, getCachedWord. Cache should expire after 24 hours.

# Prompt 11: Word repository
> Create lib/data/repositories/word_repository.dart that aggregates all data sources. The method getWordEntry(String word) should: first check word_cache, if miss then call dictionary_api + datamuse_api + translate_api + wordnik_api in parallel using Future.wait(), then cache the result and return WordEntryModel. Also create favorites_repository.dart wrapping word_db.dart favorite methods.
```

---

### Phase 5 — Domain Layer

```bash
# Prompt 12: Use cases
> Create these use case classes in lib/domain/usecases/, each with a single call() method:
> - get_suggestions.dart → calls WordListAsset.getSuggestions(prefix)
> - get_word_entry.dart → calls WordRepository.getWordEntry(word)
> - toggle_favorite.dart → calls FavoritesRepository saveFavorite or removeFavorite based on current state
> - get_all_favorites.dart → calls FavoritesRepository.getAllFavorites()
```

---

### Phase 6 — State Management (Riverpod)

```bash
# Prompt 13: Providers
> Create lib/presentation/providers/ with these Riverpod providers:
> - search_provider.dart: StateNotifierProvider managing search query string and List<String> suggestions. On query change debounce 300ms then call GetSuggestions usecase.
> - word_detail_provider.dart: FutureProvider.family<WordEntryModel, String> that calls GetWordEntry usecase.
> - favorites_provider.dart: StateNotifierProvider with List<WordEntryModel> state. Methods: loadFavorites, toggleFavorite. Refresh after every toggle.
```

---

### Phase 7 — UI Screens

```bash
# Prompt 14: App theme
> Create lib/core/theme/app_theme.dart with a dark elegant theme. Primary color deep teal (#006D77), accent color warm amber (#E9C46A), background near-black (#0D1117). Use Google Fonts - Merriweather for headings, Source Sans Pro for body. Add card styling, input decoration theme, and chip theme.

# Prompt 15: Home screen with search
> Create lib/presentation/screens/home/home_screen.dart with:
> - A FlutterTypeAhead search bar at the top with placeholder "Type a word..."
> - As user types show dropdown suggestions from search_provider
> - On suggestion tap navigate to WordDetailScreen passing the word
> - Below search show a section "Recent Searches" from shared_preferences (last 10 words)
> - FAB button navigating to FavoritesScreen
> Apply the app theme. Add smooth animations using flutter_animate on list items.

# Prompt 16: Word detail screen
> Create lib/presentation/screens/word_detail/word_detail_screen.dart that takes a word String argument. Use word_detail_provider to fetch data. Show loading shimmer while fetching. Layout from top to bottom:
> - Word title + phonetic + part of speech
> - Favorite star icon button (filled/outline based on favorites_provider)
> - Row of 5 synonym chips in amber color
> - Bangla meaning card with a Bangladesh flag emoji and Bengali text
> - Divider with label "Example Sentences"
> - List of sentence cards each with a book icon
> Handle error state with retry button.

# Prompt 17: Favorites screen
> Create lib/presentation/screens/favorites/favorites_screen.dart using favorites_provider. Show saved words as cards with word title, bangla meaning preview, and a delete icon. Tap on card navigates to WordDetailScreen. Show empty state illustration with text "No saved words yet" when list is empty. Add a search bar to filter favorites locally.
```

---

### Phase 8 — Navigation & Final Wiring

```bash
# Prompt 18: App router
> Create lib/core/router/app_router.dart using Navigator 2.0 or GoRouter with named routes: / for HomeScreen, /word/:word for WordDetailScreen, /favorites for FavoritesScreen. Wire it in main.dart with ProviderScope wrapping the app.

# Prompt 19: Wire everything in main.dart
> Update main.dart to initialize sqflite database on app startup, wrap app in ProviderScope, set app title to EnglishBuddy, apply the dark theme from app_theme.dart, and set home to HomeScreen.
```

---

### Phase 9 — Testing & Polish

```bash
# Prompt 20: Error handling audit
> Review all API datasource files and add consistent error handling. Every API method should catch DioException and return safe defaults. Add a connectivity check utility in core/utils/connectivity.dart that checks internet before API calls and throws a readable NoInternetException.

# Prompt 21: Loading states
> Add shimmer loading effect to WordDetailScreen while data loads. Use the shimmer package. Create a ShimmerWordDetail widget that mimics the layout of the word detail screen with grey placeholder blocks for each section.

# Prompt 22: Unit tests
> Write unit tests in test/ folder for:
> - WordListAsset.getSuggestions() with prefix "ad" should return words starting with ad
> - FavoritesRepository save and remove operations using an in-memory mock db
> - word_detail_provider returns correct WordEntryModel structure when all APIs succeed
> Use mocktail for mocking.
```

---

## 🔁 Useful Iterative Prompts

```bash
# Debug a specific issue
> The FlutterTypeAhead dropdown closes immediately after showing suggestions. Fix the issue in search_bar_widget.dart without changing the existing API structure.

# Improve UI
> Make the synonym chips in word_detail_screen horizontally scrollable and add a subtle bounce animation when they appear using flutter_animate.

# Add a feature
> Add a "Copy sentence" button to each sentence card in word_detail_screen that copies the sentence text to clipboard and shows a SnackBar confirmation.

# Refactor
> Refactor word_repository.dart to use a Result<T> pattern instead of throwing exceptions. Create a Result class in core/utils/result.dart with Success and Failure subtypes.
```

---

## 📱 Build & Run

```bash
# Run on device
flutter run

# Build APK
flutter build apk --release

# Analyze code
flutter analyze

# Run tests
flutter test
```

---

## 💡 Pro Tips for Claude Code CLI

```bash
# Always give file context when fixing bugs
> Look at lib/data/repositories/word_repository.dart and fix the null check error on line 34

# Use /add to include files in context
/add lib/data/datasources/remote/dictionary_api.dart
> Now refactor this to use a Result type instead of throwing

# Ask for explanation before implementing
> Before writing code, explain how you'll structure the Riverpod provider for word detail with caching

# Generate in small chunks, not everything at once
> Only implement the getSuggestions method for now, leave the rest as TODO stubs
```

Want me to write the actual starter code for any specific phase so you can paste it as your first prompt to Claude Code?