import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/vault.dart';
import '../models/photo.dart';
import '../services/auth_service.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import 'family_link_sheet.dart';
import 'protected_viewer_screen.dart';
import 'share_sheet.dart';

/// Home screen — the owner's private vault of protected photos.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  Future<void> _addPhotos(BuildContext context) async {
    final vault = context.read<Vault>();
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      maxWidth: 2400,
      imageQuality: 90,
    );
    if (picked.isEmpty || !context.mounted) return;

    // Ask when the photo(s) were taken (drives the timeline + age), plus a
    // caption when it's a single photo.
    final meta = await _askPhotoMeta(context, askCaption: picked.length == 1);
    if (meta == null || !context.mounted) return; // cancelled / gone
    final caption = meta.caption;
    final takenAt = meta.date;

    final messenger = ScaffoldMessenger.of(context);
    final plural = picked.length > 1 ? '${picked.length} photos' : 'photo';
    messenger.showSnackBar(
      SnackBar(content: Text('Uploading $plural…')),
    );
    try {
      for (final file in picked) {
        final bytes = await file.readAsBytes();
        await vault.addPhoto(bytes, caption, takenAt: takenAt);
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Added $plural')));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<_PhotoMeta?> _askPhotoMeta(BuildContext context,
      {required bool askCaption}) {
    return showDialog<_PhotoMeta>(
      context: context,
      builder: (_) => _AddPhotoDialog(askCaption: askCaption),
    );
  }

  Future<void> _inviteCoOwner(BuildContext context) async {
    final vault = context.read<Vault>();
    final messenger = ScaffoldMessenger.of(context);
    String token;
    try {
      token = await vault.createInvite();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not create invite: $e')),
      );
      return;
    }
    if (!context.mounted) return;
    final url = ShareService.inviteLinkFor(token);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Invite a co-owner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send this link to your partner. They open it, create their own '
              'account, and can then add photos to this same vault.',
              style: TextStyle(color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                url,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Invite link copied')),
              );
            },
            child: const Text('Copy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ShareService.shareInvite(token);
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Peekaboo'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.mint.withOpacity(0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 13, color: AppTheme.mint),
                  SizedBox(width: 4),
                  Text('Protected',
                      style: TextStyle(color: AppTheme.mint, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: 'Family gallery link',
            onPressed: () => showFamilyLinkSheet(context, context.read<Vault>()),
          ),
          PopupMenuButton<String>(
            color: AppTheme.surfaceHigh,
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (v) {
              if (v == 'signout') AuthService.signOut();
              if (v == 'invite') _inviteCoOwner(context);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  AuthService.user?.email ?? 'Signed in',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'invite',
                child: Row(
                  children: [
                    Icon(Icons.group_add_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Invite co-owner'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Sign out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPhotos(context),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add photos'),
      ),
      body: Consumer<Vault>(
        builder: (context, vault, _) {
          if (vault.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vault.error != null) return _ErrorState(message: vault.error!);
          if (vault.photos.isEmpty) return const _EmptyState();
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.82,
            ),
            itemCount: vault.photos.length,
            itemBuilder: (context, i) =>
                _PhotoCard(photo: vault.photos[i], vault: vault),
          );
        },
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final Photo photo;
  final Vault vault;
  const _PhotoCard({required this.photo, required this.vault});

  void _open(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProtectedViewerScreen(
        image: photo.imageProvider,
        caption: photo.caption,
        watermarkName: 'Preview',
        subjectRects: photo.subjectRects,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => _open(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(image: photo.imageProvider, fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      photo.caption.isEmpty ? 'Untitled' : photo.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.ios_share_rounded, size: 20),
                    tooltip: 'Share',
                    onPressed: () => showShareSheet(context, vault, photo),
                  ),
                  PopupMenuButton<String>(
                    color: AppTheme.surfaceHigh,
                    onSelected: (v) {
                      if (v == 'delete') vault.removePhoto(photo);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Caption + "date taken" collected before an upload.
class _PhotoMeta {
  final String caption;
  final DateTime date;
  const _PhotoMeta(this.caption, this.date);
}

class _AddPhotoDialog extends StatefulWidget {
  final bool askCaption;
  const _AddPhotoDialog({required this.askCaption});

  @override
  State<_AddPhotoDialog> createState() => _AddPhotoDialogState();
}

class _AddPhotoDialogState extends State<_AddPhotoDialog> {
  final _caption = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 18),
      lastDate: now,
      helpText: 'When was this taken?',
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _label(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dd = DateTime(d.year, d.month, d.day);
    final diff = today.difference(dd).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(widget.askCaption ? 'Photo details' : 'When were these taken?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.askCaption) ...[
            TextField(
              controller: _caption,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Caption (optional)',
                hintText: 'First steps 🐣',
              ),
            ),
            const SizedBox(height: 12),
          ],
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickDate,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 18, color: AppTheme.textMuted),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Taken: ${_label(_date)}')),
                  const Icon(Icons.edit_outlined,
                      size: 16, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () =>
              Navigator.pop(context, _PhotoMeta(_caption.text, _date)),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text("Couldn't load your vault",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<Vault>().load(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.child_care_rounded,
                  size: 48, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text('Your vault is empty',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Add a photo to keep it protected. You can share it as a private, '
              'watermarked link that can’t be posted to social feeds.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
