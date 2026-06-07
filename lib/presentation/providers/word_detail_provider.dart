import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/word_entry_model.dart';
import '../../domain/usecases/get_word_entry.dart';

final wordDetailProvider = FutureProvider.family<WordEntryModel, String>((ref, word) async {
  return GetWordEntry()(word);
});
