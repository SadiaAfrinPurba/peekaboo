import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges to native screenshot defenses. The honest per-platform reality:
///
///  • Android — we set FLAG_SECURE, which genuinely BLOCKS screenshots and
///    screen recording, and hides the app in the recents switcher.
///  • iOS — screenshots CANNOT be blocked by any app. We instead DETECT them
///    (`userDidTakeScreenshotNotification`) and fire [onScreenshot] so the UI
///    can blur the photo and warn the sender.
///  • Web / PWA — no capture API exists at all; this is a no-op. The watermark
///    overlay is the only protection here.
class ScreenProtection {
  ScreenProtection._();
  static final ScreenProtection instance = ScreenProtection._();

  static const MethodChannel _channel = MethodChannel('peekaboo/screen');

  /// Called when iOS reports the user took a screenshot.
  VoidCallback? onScreenshot;

  bool get canBlockScreenshots =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get canDetectScreenshots =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Human-readable status shown in the viewer's protection banner.
  String get statusLabel {
    if (kIsWeb) return 'View-only • watermarked';
    if (canBlockScreenshots) return 'Screenshots blocked';
    if (canDetectScreenshots) return 'Screenshot alerts on';
    return 'Watermarked';
  }

  void init() {
    if (kIsWeb) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'screenshot') {
        onScreenshot?.call();
      }
      return null;
    });
  }

  /// Turn protection on while a photo is on screen.
  Future<void> enable() async {
    if (!canBlockScreenshots) return;
    try {
      await _channel.invokeMethod('secure', true);
    } on PlatformException {
      // Native side not wired on this build — safe to ignore.
    }
  }

  /// Turn protection off when leaving the viewer.
  Future<void> disable() async {
    if (!canBlockScreenshots) return;
    try {
      await _channel.invokeMethod('secure', false);
    } on PlatformException {
      /* ignore */
    }
  }
}
