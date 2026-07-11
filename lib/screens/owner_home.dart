import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/vault.dart';
import '../services/auth_service.dart';
import 'gallery_screen.dart';
import 'login_screen.dart';

/// The owner area (everything that isn't a share link). Gates access behind
/// authentication and only builds the [Vault] once a private, claimed account
/// is signed in.
class OwnerHome extends StatefulWidget {
  const OwnerHome({super.key});

  @override
  State<OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends State<OwnerHome> {
  StreamSubscription<AuthState>? _sub;
  Vault? _vault;

  @override
  void initState() {
    super.initState();
    _sub = AuthService.changes.listen((_) {
      if (!mounted) return;
      // Tear the vault down on sign-out / loss of a claimed session.
      if (!AuthService.isClaimed && _vault != null) {
        _vault!.dispose();
        _vault = null;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _vault?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isSignedIn) {
      return const LoginScreen(mode: LoginMode.signIn);
    }
    if (AuthService.isAnonymous) {
      // Signed in anonymously (owns the photos) but not yet private.
      return const LoginScreen(mode: LoginMode.claim);
    }

    // Claimed, private account → build the vault once and show the gallery.
    _vault ??= Vault()..load();
    return ChangeNotifierProvider<Vault>.value(
      value: _vault!,
      child: const GalleryScreen(),
    );
  }
}
