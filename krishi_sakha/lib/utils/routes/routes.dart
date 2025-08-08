import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:krishi_sakha/screens/home/home_screen.dart';
import 'package:krishi_sakha/screens/login/login_screen.dart';
import 'package:krishi_sakha/screens/models/model_list_screen.dart';
import 'package:krishi_sakha/screens/onboarding/onboarding.dart';
import 'package:krishi_sakha/screens/permission/permission_screen.dart';

// Route paths
class AppRoutes {
  static const String onboarding = '/';
  static const String permission = '/permission';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String chatHistory = '/chat-history';
  static const String settings = '/settings';
  static const String download = '/download';
  static const String search = '/search';
  static const String login = "/login";
  static const String selector = "/selector";
  
}

// GoRouter configuration
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.onboarding,
  routes: [
    // Onboarding route
    GoRoute(
      path: AppRoutes.onboarding,
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),

    // Permission route
    GoRoute(
      path: AppRoutes.permission,
      name: 'permission',
      builder: (context, state) => const PermissionScreen(),
    ),

    // Home route (placeholder for now)
    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
  GoRoute(
      path: AppRoutes.selector,
      name: 'selector',
      builder: (context, state) => ModelListScreen(),
    ),

  GoRoute(path: AppRoutes.login, name: 'login', builder: (context, state) => const LoginScreen()),

  

    // Settings route (placeholder for now)
    GoRoute(
      path: AppRoutes.settings,
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),

    // Download route (placeholder for now)
    GoRoute(
      path: AppRoutes.download,
      name: 'download',
      builder: (context, state) => const DownloadScreen(),
    ),

    // Search route (placeholder for now)
    GoRoute(
      path: AppRoutes.search,
      name: 'search',
      builder: (context, state) => const SearchScreen(),
    ),
 
    
  ],

  // Error handling
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Page not found: ${state.uri}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.onboarding),
            child: const Text('Go to Home'),
          ),
        ],
      ),
    ),
  ),
);

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: const Color(0xFF101820),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Chat Screen - Coming Soon',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF101820),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Settings Screen - Coming Soon',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

class DownloadScreen extends StatelessWidget {
  const DownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Models'),
        backgroundColor: const Color(0xFF101820),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Download Screen - Coming Soon',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: const Color(0xFF101820),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Search Screen - Coming Soon',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
