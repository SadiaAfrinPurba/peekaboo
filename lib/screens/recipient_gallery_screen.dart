import 'package:flutter/material.dart';

import '../data/gallery_api.dart';
import '../services/age.dart';
import '../services/local_store.dart';
import '../services/pwa_install.dart';
import '../services/viewer_identity.dart';
import '../theme/app_theme.dart';
import 'protected_viewer_screen.dart';

/// Landing screen for the permanent family-gallery link (`/#/g/<token>`).
///
/// Resolves the token through the token-gated `get_gallery` RPC — no login. The
/// same link works for every recipient; each viewer names themselves once so
/// the watermark can tag who's looking, and (on a supported browser) is invited
/// to install the app to their home screen.
class RecipientGalleryScreen extends StatefulWidget {
  final String token;
  const RecipientGalleryScreen({super.key, required this.token});

  @override
  State<RecipientGalleryScreen> createState() => _RecipientGalleryScreenState();
}

class _RecipientGalleryScreenState extends State<RecipientGalleryScreen> {
  late Future<GalleryFeed> _future;
  String? _viewerName;

  @override
  void initState() {
    super.initState();
    _future = fetchGallery(widget.token);
    _viewerName = ViewerIdentity.name;
  }

  void _saveName(String name) {
    ViewerIdentity.save(name);
    setState(() => _viewerName = ViewerIdentity.name);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GalleryFeed>(
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
            title: "Couldn't open this gallery",
            body: 'Please check your connection and try again.',
          );
        }

        final feed = snap.data!;
        if (!feed.found) {
          return const _Unavailable(
            icon: Icons.link_off_rounded,
            title: 'Link not found',
            body: 'This gallery link is invalid.',
          );
        }
        if (!feed.active) {
          return const _Unavailable(
            icon: Icons.lock_outline_rounded,
            title: 'This gallery is paused',
            body: 'The link has been turned off. Ask the family to re-enable it.',
          );
        }

        // Ask the viewer's name once before showing photos.
        if (_viewerName == null) {
          return _NamePrompt(babyName: feed.babyName, onSubmit: _saveName);
        }

        return _GalleryView(feed: feed, viewerName: _viewerName!);
      },
    );
  }
}

/// One-time "who's viewing?" screen. The name is saved on this device and
/// stamped into each photo's watermark.
class _NamePrompt extends StatefulWidget {
  final String babyName;
  final ValueChanged<String> onSubmit;
  const _NamePrompt({required this.babyName, required this.onSubmit});

  @override
  State<_NamePrompt> createState() => _NamePromptState();
}

class _NamePromptState extends State<_NamePrompt> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) return;
    widget.onSubmit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final who = widget.babyName.isEmpty ? 'the family' : widget.babyName;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
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
                  child: const Icon(Icons.favorite_rounded,
                      size: 40, color: AppTheme.primary),
                ),
                const SizedBox(height: 22),
                Text("$who's photos",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                  'Welcome 💛 What should we call you? Your name is added quietly '
                  'to the photos you view, so the family knows who has seen them.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, height: 1.4),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Grandma',
                    filled: true,
                    fillColor: AppTheme.surfaceHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('View photos'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DaySection {
  final DateTime day;
  final List<GalleryPhoto> photos;
  const _DaySection(this.day, this.photos);
}

class _GalleryView extends StatefulWidget {
  final GalleryFeed feed;
  final String viewerName;
  const _GalleryView({required this.feed, required this.viewerName});

  @override
  State<_GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<_GalleryView> {
  static const _installDismissedKey = 'peekaboo_install_dismissed';
  bool _showInstall = false;

  @override
  void initState() {
    super.initState();
    // Install the app under the baby's name (home-screen label), not "Peekaboo".
    if (widget.feed.babyName.isNotEmpty) {
      PwaInstall.setAppName(widget.feed.babyName);
    }
    // Offer "Add to Home Screen" on the first visit (once), where supported.
    final dismissed = getLocal(_installDismissedKey) == '1';
    final canOffer = !PwaInstall.isStandalone &&
        (PwaInstall.canInstall || PwaInstall.isIosSafari);
    _showInstall = canOffer && !dismissed;
  }

  String get _appName =>
      widget.feed.babyName.isEmpty ? 'Peekaboo' : widget.feed.babyName;

  void _dismissInstall() {
    setLocal(_installDismissedKey, '1');
    setState(() => _showInstall = false);
  }

  Future<void> _install() async {
    if (PwaInstall.canInstall) {
      await PwaInstall.promptInstall();
      _dismissInstall();
    } else if (PwaInstall.isIosSafari) {
      showDialog<void>(
        context: context,
        builder: (_) => _IosInstallHint(appName: _appName),
      );
      _dismissInstall();
    }
  }

  List<_DaySection> get _sections {
    final map = <String, List<GalleryPhoto>>{};
    final order = <String>[];
    for (final p in widget.feed.photos) {
      final d = DateTime(p.takenAt.year, p.takenAt.month, p.takenAt.day);
      final key = d.toIso8601String();
      if (!map.containsKey(key)) {
        map[key] = [];
        order.add(key);
      }
      map[key]!.add(p);
    }
    return [
      for (final k in order) _DaySection(DateTime.parse(k), map[k]!),
    ];
  }

  void _open(GalleryPhoto p) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProtectedViewerScreen(
        image: NetworkImage(p.imageUrl),
        caption: p.caption,
        watermarkName: widget.viewerName,
        isRecipientView: true,
        subjectRects: p.subjectRects,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final feed = widget.feed;
    final title = feed.babyName.isEmpty ? 'Peekaboo' : "${feed.babyName}'s photos";
    final sections = _sections;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            const Icon(Icons.lock_outline, size: 15, color: AppTheme.mint),
          ],
        ),
      ),
      body: feed.photos.isEmpty
          ? const _EmptyGallery()
          : Column(
              children: [
                if (_showInstall)
                  _InstallBanner(
                    appName: _appName,
                    onAdd: _install,
                    onDismiss: _dismissInstall,
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: sections.length,
                    itemBuilder: (context, i) => _DaySectionView(
                      section: sections[i],
                      birthdate: feed.birthdate,
                      onOpen: _open,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DaySectionView extends StatelessWidget {
  final _DaySection section;
  final DateTime? birthdate;
  final void Function(GalleryPhoto) onOpen;
  const _DaySectionView({
    required this.section,
    required this.birthdate,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cross = width > 900 ? 4 : (width > 600 ? 3 : 2);
    final age = ageAt(birthdate, section.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
          child: Row(
            children: [
              Text(dayLabel(section.day),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              if (age.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(age,
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: section.photos.length,
          itemBuilder: (context, i) {
            final p = section.photos[i];
            return _GalleryTile(photo: p, onTap: () => onOpen(p));
          },
        ),
      ],
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final GalleryPhoto photo;
  final VoidCallback onTap;
  const _GalleryTile({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: AppTheme.surfaceHigh,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(image: NetworkImage(photo.imageUrl), fit: BoxFit.cover),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.lock, size: 12, color: Colors.white),
                ),
              ),
              if (photo.caption.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Text(
                      photo.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstallBanner extends StatelessWidget {
  final String appName;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;
  const _InstallBanner(
      {required this.appName, required this.onAdd, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.add_to_home_screen_rounded,
              color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Add $appName to your home screen for one-tap access.',
              style: const TextStyle(height: 1.3, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(onPressed: onAdd, child: const Text('Add')),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'Not now',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _IosInstallHint extends StatelessWidget {
  final String appName;
  const _IosInstallHint({required this.appName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add to Home Screen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('On iPhone/iPad, add $appName like this:',
              style: const TextStyle(height: 1.4)),
          const SizedBox(height: 12),
          const Row(children: [
            Icon(Icons.ios_share_rounded, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('1. Tap the Share button in Safari')),
          ]),
          const SizedBox(height: 8),
          const Row(children: [
            Icon(Icons.add_box_outlined, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('2. Choose "Add to Home Screen"')),
          ]),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 48, color: AppTheme.textMuted),
            SizedBox(height: 16),
            Text('No photos yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text('Check back soon — new photos will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, height: 1.4)),
          ],
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
                  style:
                      const TextStyle(color: AppTheme.textMuted, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}
