import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

enum LoginMode {
  /// No session — sign in, or create a new co-owner account.
  signIn,

  /// An anonymous session that owns the photos — attach email + password.
  claim,
}

/// Owner / co-owner auth with email + password.
class LoginScreen extends StatefulWidget {
  final LoginMode mode;

  /// Optional message shown above the form (e.g. when arriving from an invite).
  final String? intro;

  const LoginScreen({super.key, required this.mode, this.intro});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _createAccount = false; // sign-in mode: toggle between sign in / sign up
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _isClaim => widget.mode == LoginMode.claim;

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_isClaim) {
        await AuthService.claim(email, password);
      } else if (_createAccount) {
        await AuthService.signUp(email, password);
        // If email confirmation is on, there's no session yet.
        if (!AuthService.isSignedIn && mounted) {
          setState(() {
            _busy = false;
            _notice = 'Account created. Check your email to confirm, then sign '
                'in. (Tip: turn off "Confirm email" in Supabase for instant '
                'sign-up.)';
            _createAccount = false;
          });
          return;
        }
      } else {
        await AuthService.signIn(email, password);
      }
      // Success flows are picked up by OwnerHome's auth listener; nothing else
      // to do here. Guard setState in case we're still mounted.
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _friendly(e);
      });
    }
  }

  String _friendly(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('invalid login') || s.contains('invalid credentials')) {
      return 'Wrong email or password.';
    }
    if (s.contains('already registered') || s.contains('already been')) {
      return 'That email already has an account — sign in instead.';
    }
    if (s.contains('weak') || s.contains('password')) {
      return 'Please choose a stronger password (6+ characters).';
    }
    if (s.contains('rate') || s.contains('too many')) {
      return 'Too many attempts — wait a minute and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _formView(),
          ),
        ),
      ),
    );
  }

  Widget _formView() {
    final String title;
    final String subtitle;
    final String action;
    if (_isClaim) {
      title = 'Secure your vault';
      subtitle = 'Set an email + password to lock this vault to you. Your '
          'existing photos stay exactly as they are — same account, now private '
          'and reachable from any device.';
      action = 'Secure my vault';
    } else if (_createAccount) {
      title = 'Create your account';
      subtitle = 'Make an account to join the shared vault.';
      action = 'Create account';
    } else {
      title = 'Welcome back';
      subtitle = 'Sign in to your vault.';
      action = 'Sign in';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(_isClaim ? Icons.lock_outline_rounded : Icons.login_rounded,
              size: 40, color: AppTheme.primary),
        ),
        const SizedBox(height: 22),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMuted, height: 1.4)),
        if (widget.intro != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(widget.intro!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
        const SizedBox(height: 22),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'you@example.com',
            filled: true,
            fillColor: AppTheme.surfaceHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Password',
            filled: true,
            fillColor: AppTheme.surfaceHigh,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              icon: Icon(_obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.secondary, fontSize: 13)),
        ],
        if (_notice != null) ...[
          const SizedBox(height: 12),
          Text(_notice!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.mint, fontSize: 13)),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(action),
          ),
        ),
        if (!_isClaim) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _createAccount = !_createAccount;
                      _error = null;
                      _notice = null;
                    }),
            child: Text(_createAccount
                ? 'Have an account? Sign in'
                : 'New co-owner? Create an account'),
          ),
        ],
        if (_isClaim) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => AuthService.signOut(),
            child: const Text('Sign out instead'),
          ),
        ],
      ],
    );
  }
}
