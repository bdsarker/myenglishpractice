import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
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
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Pinned, not just defaulted: with no darkTheme a phone in dark mode would
      // still fall back to Flutter's own dark palette.
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
