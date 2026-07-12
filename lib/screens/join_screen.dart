import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/vault.dart';
import '../services/auth_service.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'owner_home.dart';

/// Landing screen for a co-owner invite link (`/#/join/<token>`).
///
/// If the visitor isn't signed in yet, they sign in or create an account first
/// (the token is stashed so it survives the round-trip); once they have a real
/// account we redeem the invite and drop them into the shared vault.
class JoinScreen extends StatefulWidget {
  final String token;
  const JoinScreen({super.key, required this.token});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  StreamSubscription<AuthState>? _sub;
  bool _redeeming = false;
  String? _result; // 'ok' | 'invalid' | 'expired' | 'error'

  @override
  void initState() {
    super.initState();
    // Remember the invite so it's redeemed even if auth navigates away.
    setLocal(kPendingInviteKey, widget.token);
    _sub = AuthService.changes.listen((_) {
      if (mounted) _maybeRedeem();
    });
    _maybeRedeem();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _maybeRedeem() async {
    if (!AuthService.isClaimed) return; // wait for a real (email) account
    if (_redeeming || _result == 'ok') return;
    setState(() => _redeeming = true);
    try {
      final res = await Supabase.instance.client
          .rpc('redeem_invite', params: {'p_token': widget.token});
      final ok = res is Map && res['ok'] == true;
      if (ok) setLocal(kPendingInviteKey, '');
      if (!mounted) return;
      setState(() {
        _result = ok
            ? 'ok'
            : (res is Map ? (res['error']?.toString() ?? 'error') : 'error');
        _redeeming = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _result = 'error';
        _redeeming = false;
      });
    }
  }

  void _openVault() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OwnerHome()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isClaimed) {
      return const LoginScreen(
        mode: LoginMode.signIn,
        intro: 'You\'ve been invited to a shared Peekaboo vault. Sign in or '
            'create an account to join it.',
      );
    }

    if (_result == null || _redeeming) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_result == 'ok') {
      return _Message(
        icon: Icons.group_add_rounded,
        color: AppTheme.mint,
        title: "You're in!",
        body: 'You can now add and manage photos in the shared vault.',
        actionLabel: 'Open the vault',
        onAction: _openVault,
      );
    }

    final expired = _result == 'expired';
    return _Message(
      icon: expired ? Icons.timer_off_outlined : Icons.link_off_rounded,
      color: AppTheme.textMuted,
      title: expired ? 'Invite expired' : 'Invite not valid',
      body: 'Ask for a fresh invite link.',
      actionLabel: 'Go to my vault',
      onAction: _openVault,
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  const _Message({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 22),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(body,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: AppTheme.textMuted, height: 1.4)),
              const SizedBox(height: 22),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
