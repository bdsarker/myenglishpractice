# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Word Depot** — a Flutter English-learning app (Bengali speakers). Type a word, get its
pronunciation, part of speech, English + Bangla definition, synonyms, and real example
sentences; save favourites; hear any of it read aloud. Flutter 3.44 stable, Dart SDK ^3.9.2.
Original product brief and phase-by-phase build log: [plan/plan.md](plan/plan.md) (historical —
several APIs named there were later replaced).

## Commands

```bash
flutter pub get
flutter run                          # debug on the attached device
flutter analyze                      # must be "No issues found!"
flutter test                         # whole suite
flutter test test/data/word_repository_test.dart          # one file
flutter test --plain-name "substring of the test name"    # one test
flutter build apk --release          # ~4-5 min cold
flutter build ios --release
```

Tests must run from the project root — [test/android_manifest_test.dart](test/android_manifest_test.dart)
reads a file by relative path.

Two generators, both manual and both rarely needed:

```bash
dart run flutter_launcher_icons          # regenerate launcher icons from assets/icon/
dart run tool/generate_word_list.dart    # regenerate assets/data/words.json (network)
```

`.github/workflows/dart.yml` is still the stock Dart template — it runs `dart analyze` /
`dart test`, not the Flutter equivalents, so it is **not** a mirror of the commands above.

## Architecture

Clean-architecture layering, thin by design. A read flows straight down and back:

```
screen (ConsumerWidget)  →  provider  →  usecase  →  repository  →  datasource
```

- **`lib/core/`** — `constants` (all tunable limits live in `AppConstants`), `router`
  (three flat go_router routes), `theme`, `services/speech_service.dart`, `utils`.
- **`lib/data/`** — `models` (plain classes, hand-written `fromJson`/`copyWith`),
  `datasources/remote` (one class per API, each owning its own `Dio`),
  `datasources/local` (`WordDb` sqflite, `WordListAsset` bundled JSON), `repositories`.
- **`lib/domain/usecases/`** — one callable class each (`GetWordEntry()(word)`). They add no
  logic beyond `ToggleFavorite`'s read-then-flip; they exist to keep screens off repositories.
- **`lib/presentation/`** — `providers` + `screens`.

**Dependency injection is by optional named constructor parameter**, not a container: every
repository, usecase and datasource default-constructs its collaborators
(`WordRepository({WordDb? db, ...}) : _db = db ?? WordDb()`). Tests pass fakes in; production
passes nothing. `WordDb` and `ConnectivityUtil` are singletons behind `factory` constructors.

### The four APIs

[`WordRepository.getWordEntry`](lib/data/repositories/word_repository.dart#L51) fans all four
out through a single `Future.wait`:

| datasource | endpoint | supplies |
|---|---|---|
| `DictionaryApi` | `api.dictionaryapi.dev` | phonetic, part of speech, definition, curated examples |
| `DatamuseApi` | `api.datamuse.com` | synonyms |
| `TranslateApi` | `api.mymemory.translated.net` | Bangla meaning |
| `SentenceApi` | `tatoeba.org` | corpus example sentences (CC BY 2.0 FR — the attribution on the detail screen is required) |

All are keyless and unauthenticated. **`DictionaryApi` is the only one that throws**; the other
three swallow their own errors and return empty. That asymmetry is deliberate — see below.

### Invariants worth knowing before you change anything

**"Not found" and "couldn't reach it" must never merge.** `DictionaryApi.lookup` returns `null`
for a word with no entry and throws `DictionaryUnavailableException` when the service failed
(4 retries first). `WordEntryModel.found` carries the former to the UI. Collapsing these makes
ordinary words render as typos, and caches a transient 5xx as "this word doesn't exist" for 24
hours — which is why misses are never cached.

**Anything that throws inside that `Future.wait` blanks the entire screen**, meaning *and*
sentences both. If you make another datasource throw, expect that blast radius.

**`ConnectivityUtil.checkConnectivity()` runs before the fan-out** so being offline reports as
"No internet connection" rather than a dictionary error. It only sees the `connectivity_plus`
verdict, not reachability — a phone on wifi with no route still falls through to the dictionary
error path.

**Known gap: `word_cache` silently drops three fields.** The table in
[word_db.dart](lib/data/datasources/local/word_db.dart#L33-L41) has no columns for `phonetic`,
`part_of_speech` or `english_definition`, and the cache-hit branch doesn't reconstruct them, so
re-opening a word within 24 hours loses its pronunciation and English definition. Fixing it
needs a schema migration and a DB `version` bump (currently 1).

**`assets/data/words.json` order is load-bearing.** It is descending frequency, not
alphabetical; `WordListAsset.getSuggestions` prefix-filters and takes the first N, so file order
*is* the ranking. `test/data/word_list_asset_test.dart` asserts this.

### Speech (flutter_tts)

`Speaker` in [speech_service.dart](lib/core/services/speech_service.dart) is an interface purely
so tests can substitute one — flutter_tts talks over a MethodChannel that doesn't exist under
`flutter test`. **Widget tests must override `speakerProvider`** with
[test/support/fake_speaker.dart](test/support/fake_speaker.dart) or they'll hang.

`speechProvider` holds the *text* currently being spoken (`String?`) — the word and every
sentence are already distinct strings, so buttons compare against it to decide play vs stop.
One `TtsSpeaker` for the whole app; two would each hold an iOS audio session and talk over each
other. Rate is `0.5` on both platforms (flutter_tts doubles the Android value, so no platform
branch is needed).

### Theme

**Light only, deliberately pinned** — `themeMode: ThemeMode.light` with no `darkTheme`, so a
phone in dark mode can't fall back to Flutter's palette. `AppTheme` exposes semantic ink
constants (`ink`, `inkMuted`, `inkFaint`, `line`, `accent` vs `accentInk`) rather than
`Colors.whiteNN` scattered through widgets.

[test/core/theme_test.dart](test/core/theme_test.dart) asserts every foreground clears WCAG AA
(4.5:1) on **both** the white card and the off-white scaffold, and that flat cards keep their
hairline border. It pins the property, not the hex, so retuning the palette is free — but a
swatch nobody can read fails. `accent` (the brand amber) is a fill only; use `accentInk` for
text. If a colour fails, fix the colour, not the test.

## Platform gotchas

**`android/app/src/main/AndroidManifest.xml` must keep `INTERNET`.** Flutter's template declares
it in `src/debug` and `src/profile` only, so release builds silently ship with no network at all
while `flutter analyze`, every test and every `flutter run` keep passing. This cost a shipped
broken APK once; [test/android_manifest_test.dart](test/android_manifest_test.dart) is the only
thing guarding it. The `<queries>` block also needs its `TTS_SERVICE` intent — Android 11+ hides
other packages, and without it flutter_tts does nothing at all with no error.

**The Android toolchain is held below Flutter's template on purpose.** Gradle 8.14.3 /
AGP 8.11.1 / Kotlin 2.2.20, versus the template's 9.1.0 / 9.0.1 / 2.3.20. AGP 9 drops Java 8
source/target compatibility and a plugin still compiles with it (the `source value 8 is obsolete`
warning in every build). Don't "helpfully" bump it — see the comment in
[android/settings.gradle.kts](android/settings.gradle.kts#L22-L26).

**`dart run flutter_launcher_icons` corrupts the Xcode project.** It overwrites
`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES` with `= AppIcon` in
`ios/Runner.xcodeproj/project.pbxproj` (a string replace hitting the wrong key). Check
`git diff` on that file after every run and revert those hunks. iOS also uses a separate
pre-flattened `image_path_ios` source because 0.14.4's `background_color_ios` is ignored and
flattens to a green chroma key instead.

Android `minSdk`/`targetSdk`/`compileSdk` all follow the Flutter defaults; iOS deployment target
is 13.0.

## Testing notes

- 92 tests. `mocktail` for mocks, `Dio` + a stubbed adapter or a fake for HTTP.
- **Anything that builds `ThemeData` must be `testWidgets`, not `test`** — it resolves
  GoogleFonts, which reaches for the network; a bare unit test has no binding to absorb the
  async failure. Also set `GoogleFonts.config.allowRuntimeFetching = false` in `setUpAll`.
- Widget tests inject via `ProviderScope(overrides: [...])` — see
  [test/presentation/word_detail_test.dart](test/presentation/word_detail_test.dart#L43-L50) for
  the full pattern (`wordDetailProvider(word).overrideWith`, `favoritesProvider`,
  `speakerProvider`).
- `google_fonts` fetches typefaces at runtime, so headings render in the system fallback until
  the network answers. Bundling them as assets has been discussed but not done.
