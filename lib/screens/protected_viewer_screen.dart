import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/screen_protection.dart';
import '../theme/app_theme.dart';
import '../widgets/watermark_overlay.dart';

/// Full-screen protected viewer. Enables native screenshot blocking on entry,
/// stamps a per-viewer watermark, and (on iOS) blurs + warns if a screenshot
/// is detected.
class ProtectedViewerScreen extends StatefulWidget {
  /// The image source — in-memory bytes (owner) or a signed URL (recipient).
  final ImageProvider image;

  final String caption;

  /// Name stamped into the watermark — the recipient for a shared link, or
  /// "Preview" when the owner is viewing their own photo.
  final String watermarkName;

  /// True when opened from a share link (adds "shared with you" framing).
  final bool isRecipientView;

  /// Face/subject regions (normalized 0..1 in image space) to keep clear of
  /// the watermark.
  final List<Rect> subjectRects;

  const ProtectedViewerScreen({
    super.key,
    required this.image,
    required this.watermarkName,
    this.caption = '',
    this.isRecipientView = false,
    this.subjectRects = const [],
  });

  @override
  State<ProtectedViewerScreen> createState() => _ProtectedViewerScreenState();
}

class _ProtectedViewerScreenState extends State<ProtectedViewerScreen> {
  final _protection = ScreenProtection.instance;
  bool _screenshotCaught = false;
  Timer? _revealTimer;

  Size? _imageSize;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;

  @override
  void initState() {
    super.initState();
    _protection.enable();
    _protection.onScreenshot = _handleScreenshot;
    _resolveImageSize();
  }

  /// Resolve the image's intrinsic size so we can map normalized face rects to
  /// the on-screen (BoxFit.contain) image rectangle.
  void _resolveImageSize() {
    if (widget.subjectRects.isEmpty) return;
    _imageStream = widget.image.resolve(const ImageConfiguration());
    _imageListener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      if (_imageSize != size) setState(() => _imageSize = size);
    });
    _imageStream!.addListener(_imageListener!);
  }

  /// Convert normalized face rects → screen rects within the fitted image, and
  /// inflate them so the whole head area is left clear.
  List<Rect> _clearRectsFor(Size viewport) {
    final imgSize = _imageSize;
    if (imgSize == null || widget.subjectRects.isEmpty) return const [];

    final sx = viewport.width / imgSize.width;
    final sy = viewport.height / imgSize.height;
    final s = sx < sy ? sx : sy; // BoxFit.contain
    final dw = imgSize.width * s;
    final dh = imgSize.height * s;
    final ox = (viewport.width - dw) / 2;
    final oy = (viewport.height - dh) / 2;

    return widget.subjectRects.map((r) {
      final rect = Rect.fromLTWH(
        ox + r.left * dw,
        oy + r.top * dh,
        r.width * dw,
        r.height * dh,
      );
      // Expand to cover forehead/hair/chin, not just the tight face box.
      return Rect.fromLTRB(
        rect.left - rect.width * 0.45,
        rect.top - rect.height * 0.75,
        rect.right + rect.width * 0.45,
        rect.bottom + rect.height * 0.55,
      );
    }).toList();
  }

  void _handleScreenshot() {
    if (!mounted) return;
    setState(() => _screenshotCaught = true);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Screenshot detected — the sender has been notified.'),
          duration: Duration(seconds: 4),
        ),
      );
    // Re-hide the blur after a moment so the legitimate viewer can keep looking.
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _screenshotCaught = false);
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _protection.onScreenshot = null;
    _protection.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The photo. Rendered from in-memory bytes — never written to disk.
          Center(
            child: InteractiveViewer(
              maxScale: 4,
              child: Image(image: widget.image, fit: BoxFit.contain),
            ),
          ),

          // Faint traceable watermark, kept clear of detected faces.
          LayoutBuilder(
            builder: (context, constraints) => WatermarkOverlay(
              label: widget.watermarkName,
              clearRects:
                  _clearRectsFor(constraints.biggest),
            ),
          ),

          // iOS screenshot response: blur + shield.
          if (_screenshotCaught)
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  alignment: Alignment.center,
                  child: const Icon(Icons.shield_outlined,
                      color: Colors.white70, size: 64),
                ),
              ),
            ),

          _topBar(context),
          _protectionBanner(),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            _circleButton(
              icon: Icons.close_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const Spacer(),
            if (widget.caption.isNotEmpty)
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.caption,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _protectionBanner() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, color: AppTheme.mint, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _protection.statusLabel,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              if (widget.isRecipientView)
                const Text('Shared with you',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withOpacity(0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
