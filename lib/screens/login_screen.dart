import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

enum LoginMode {
  /// No session — an owner signing in on a new device/browser.
  signIn,

  /// An anonymous session that owns the photos — attach an email to keep them.
  claim,
}

/// Owner sign-in / first-time vault claim, both via email magic link.
class LoginScreen extends StatefulWidget {
  final LoginMode mode;
  const LoginScreen({super.key, required this.mode});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool get _isClaim => widget.mode == LoginMode.claim;

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isClaim) {
        await AuthService.claimWithEmail(email);
      } else {
        await AuthService.sendMagicLink(email);
      }
      if (!mounted) return;
      setState(() {
        _sent = true;
        _busy = false;
      });
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
    if (!_isClaim &&
        (s.contains('not found') ||
            s.contains('signups not allowed') ||
            s.contains('user not') ||
            s.contains('otp_disabled'))) {
      return 'No vault found for that email. Use the exact email you secured '
          'your vault with.';
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
            child: _sent ? _sentView() : _formView(),
          ),
        ),
      ),
    );
  }

  Widget _formView() {
    final title = _isClaim ? 'Secure your vault' : 'Welcome back';
    final subtitle = _isClaim
        ? 'Add your email to lock this vault to you. Your existing photos stay '
            'exactly as they are — same account, now private and reachable from '
            'any device.'
        : 'Enter your email and we’ll send you a one-tap sign-in link.';
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
        const SizedBox(height: 22),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofocus: true,
          onSubmitted: (_) => _submit(),
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
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.secondary, fontSize: 13)),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_isClaim ? Icons.shield_outlined : Icons.email_outlined),
            label: Text(_busy
                ? 'Sending…'
                : (_isClaim ? 'Secure my vault' : 'Send sign-in link')),
          ),
        ),
        if (_isClaim) ...[
          const SizedBox(height: 14),
          TextButton(
            onPressed: _busy ? null : () => AuthService.signOut(),
            child: const Text('Sign out instead'),
          ),
        ],
      ],
    );
  }

  Widget _sentView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppTheme.mint.withOpacity(0.16),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_outlined,
              size: 40, color: AppTheme.mint),
        ),
        const SizedBox(height: 22),
        const Text('Check your email',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          _isClaim
              ? 'We sent a confirmation link to ${_email.text.trim()}. Tap it to '
                  'lock this vault to your email. You can then sign in from any '
                  'device.'
              : 'We sent a sign-in link to ${_email.text.trim()}. Tap it on this '
                  'device to open your vault.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textMuted, height: 1.4),
        ),
        const SizedBox(height: 22),
        TextButton(
          onPressed: () => setState(() => _sent = false),
          child: const Text('Use a different email'),
        ),
      ],
    );
  }
}
