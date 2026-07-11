import 'package:flutter/material.dart';

import 'screens/owner_home.dart';
import 'screens/recipient_gallery_screen.dart';
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

    return MaterialApp(
      title: 'Peekaboo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  /// Routes normal navigation and shared links. Shared links do NOT require the
  /// owner to be signed in:
  ///  - `/#/g/<token>` → the permanent family gallery (all photos).
  ///  - `/#/v/<token>` → a legacy single-photo share.
  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/');

    if (uri.pathSegments.length == 2) {
      final kind = uri.pathSegments.first;
      final token = uri.pathSegments[1];
      if (kind == 'g') {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RecipientGalleryScreen(token: token),
        );
      }
      if (kind == 'v') {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RecipientScreen(token: token),
        );
      }
    }

    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const OwnerHome(),
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
