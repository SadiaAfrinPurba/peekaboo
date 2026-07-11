import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/vault.dart';
import '../models/photo.dart';
import '../models/share_link.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';

/// Bottom sheet that mints a per-recipient link and offers messaging targets.
Future<void> showShareSheet(
  BuildContext context,
  Vault vault,
  Photo photo,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ShareSheet(vault: vault, photo: photo),
  );
}

class _ShareSheet extends StatefulWidget {
  final Vault vault;
  final Photo photo;
  const _ShareSheet({required this.vault, required this.photo});

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _nameController = TextEditingController();
  bool _viewOnce = false;
  bool _busy = false;
  ShareLink? _link;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final link = await widget.vault.createShare(
        widget.photo,
        _nameController.text,
        viewOnce: _viewOnce,
        expiresIn: const Duration(days: 7),
      );
      if (!mounted) return;
      setState(() {
        _link = link;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create link: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Share securely',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Send a private link — not the photo file. It opens only inside '
            'Peekaboo and can never be posted to a feed or story.',
            style: TextStyle(color: AppTheme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 18),
          if (_link == null) ..._buildForm() else ..._buildShareTargets(),
        ],
      ),
    );
  }

  List<Widget> _buildForm() {
    return [
      TextField(
        controller: _nameController,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _generate(),
        decoration: const InputDecoration(
          labelText: "Who's this for?",
          hintText: 'e.g. Grandma',
          filled: true,
          fillColor: AppTheme.surfaceHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 6),
      SwitchListTile(
        value: _viewOnce,
        onChanged: (v) => setState(() => _viewOnce = v),
        activeColor: AppTheme.primary,
        contentPadding: EdgeInsets.zero,
        title: const Text('View once'),
        subtitle: const Text('Link stops working after the first open',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _busy ? null : _generate,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.link_rounded),
          label: Text(_busy ? 'Creating…' : 'Create secure link'),
        ),
      ),
    ];
  }

  List<Widget> _buildShareTargets() {
    final link = _link!;
    final url = ShareService.linkFor(link.token);
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: AppTheme.mint, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              tooltip: 'Copy link',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied')),
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'For ${link.recipientName}${link.viewOnce ? ' • view once' : ''} • '
        'expires in 7 days',
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _target(
            'WhatsApp',
            Icons.chat_rounded,
            const Color(0xFF25D366),
            () => ShareService.shareToWhatsApp(link.token, link.recipientName),
          ),
          _target(
            'Telegram',
            Icons.send_rounded,
            const Color(0xFF29A9EA),
            () => ShareService.shareToTelegram(link.token, link.recipientName),
          ),
          _target(
            'More…',
            Icons.ios_share_rounded,
            AppTheme.secondary,
            () => ShareService.shareViaSystem(link.token, link.recipientName),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const Text(
        'Messenger & Instagram DM: tap “More…”, or copy the link and paste it '
        'into the chat.',
        style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
      ),
    ];
  }

  Widget _target(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
