import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/vault.dart';
import 'screens/gallery_screen.dart';
import 'screens/recipient_screen.dart';
import 'theme/app_theme.dart';

class PeekabooApp extends StatelessWidget {
  /// Non-null if Supabase failed to initialize at startup.
  final String? bootError;

  const PeekabooApp({super.key, this.bootError});

  @override
  Widget build(BuildContext context) {
    if (bootError != null) {
      return MaterialApp(
        title: 'Peekaboo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: _BootError(message: bootError!),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => Vault()..load(),
      child: MaterialApp(
        title: 'Peekaboo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        onGenerateRoute: _onGenerateRoute,
      ),
    );
  }

  /// Routes normal navigation and shared links. A link like
  /// `https://peekaboo.app/#/v/<token>` arrives here as `/v/<token>` and does
  /// NOT require the owner to be signed in.
  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/');

    if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'v') {
      final token = uri.pathSegments[1];
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => RecipientScreen(token: token),
      );
    }

    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const GalleryScreen(),
    );
  }
}

class _BootError extends StatelessWidget {
  final String message;
  const _BootError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              const Text("Couldn't connect to the backend",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
