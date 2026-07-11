import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/vault.dart';
import '../models/photo.dart';
import '../theme/app_theme.dart';
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

    // Ask for a caption only when adding a single photo.
    String caption = '';
    if (picked.length == 1) {
      final c = await _askCaption(context);
      if (c == null || !context.mounted) return; // cancelled / gone
      caption = c;
    }

    final messenger = ScaffoldMessenger.of(context);
    final plural = picked.length > 1 ? '${picked.length} photos' : 'photo';
    messenger.showSnackBar(
      SnackBar(content: Text('Uploading $plural…')),
    );
    try {
      for (final file in picked) {
        final bytes = await file.readAsBytes();
        await vault.addPhoto(bytes, caption);
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

  Future<String?> _askCaption(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Add a caption'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'First steps 🐣'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Add'),
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
