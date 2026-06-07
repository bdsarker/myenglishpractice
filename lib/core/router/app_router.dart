import 'package:go_router/go_router.dart';
import '../../presentation/screens/favorites/favorites_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/word_detail/word_detail_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/word/:word',
      builder: (context, state) =>
          WordDetailScreen(word: state.pathParameters['word']!),
    ),
    GoRoute(
      path: '/favorites',
      builder: (context, state) => const FavoritesScreen(),
    ),
  ],
);
