import 'package:connectivity_plus/connectivity_plus.dart';

class NoInternetException implements Exception {
  final String message = 'No internet connection. Please check your network.';

  // Surfaced directly to the user by the word detail error state.
  @override
  String toString() => message;
}

class ConnectivityUtil {
  static final ConnectivityUtil _instance = ConnectivityUtil._();
  ConnectivityUtil._();
  factory ConnectivityUtil() => _instance;

  Future<void> checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (result.contains(ConnectivityResult.none) || result.isEmpty) {
      throw NoInternetException();
    }
  }
}
