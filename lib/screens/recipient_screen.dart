import 'package:flutter/material.dart';

import '../data/shares_api.dart';
import '../theme/app_theme.dart';
import 'protected_viewer_screen.dart';

/// Landing screen for a shared link (`/#/v/<token>`).
///
/// Resolves the token through the token-gated `get_share` RPC — no login. The
/// recipient never touches the storage bucket directly; they only ever get a
/// single, expiring signed URL for this one photo.
class RecipientScreen extends StatefulWidget {
  final String token;
  const RecipientScreen({super.key, required this.token});

  @override
  State<RecipientScreen> createState() => _RecipientScreenState();
}

class _RecipientScreenState extends State<RecipientScreen> {
  late Future<SharedPhoto> _future;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _future = fetchShare(widget.token);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPhoto>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return const _Unavailable(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't open this photo",
            body: 'Please check your connection and try again.',
          );
        }

        final share = snap.data!;
        if (share.notFound) {
          return const _Unavailable(
            icon: Icons.link_off_rounded,
            title: 'Link not found',
            body: 'This photo link is invalid.',
          );
        }
        if (share.expired || share.imageUrl == null) {
          return const _Unavailable(
            icon: Icons.timer_off_outlined,
            title: 'This link has expired',
            body: 'Ask the sender to share the photo again.',
          );
        }

        if (_opened) {
          return ProtectedViewerScreen(
            image: NetworkImage(share.imageUrl!),
            watermarkName: share.recipientName,
            isRecipientView: true,
            subjectRects: share.subjectRects,
          );
        }
        return _Intro(
          share: share,
          onOpen: () => setState(() => _opened = true),
        );
      },
    );
  }
}

class _Intro extends StatelessWidget {
  final SharedPhoto share;
  final VoidCallback onOpen;
  const _Intro({required this.share, required this.onOpen});

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
                  color: AppTheme.primary.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.visibility_outlined,
                    size: 42, color: AppTheme.primary),
              ),
              const SizedBox(height: 22),
              Text('A photo for ${share.recipientName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'This photo is protected by Peekaboo. It stays inside this '
                'viewer and is watermarked to you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, height: 1.4),
              ),
              if (share.viewOnce) ...[
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('View once',
                      style:
                          TextStyle(color: AppTheme.secondary, fontSize: 12)),
                ),
              ],
              const SizedBox(height: 26),
              ElevatedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('View photo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Unavailable(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppTheme.textMuted),
              const SizedBox(height: 18),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMuted, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}
