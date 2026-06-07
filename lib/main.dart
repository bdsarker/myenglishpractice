import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/local/word_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WordDb().database; // warm up the database on startup
  runApp(const ProviderScope(child: EnglishBuddyApp()));
}

class EnglishBuddyApp extends StatelessWidget {
  const EnglishBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EnglishBuddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
