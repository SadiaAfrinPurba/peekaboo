import 'pwa_install_stub.dart'
    if (dart.library.js) 'pwa_install_web.dart' as impl;

/// Bridges the browser's "Add to Home Screen" (PWA install) flow.
///
/// On Android/Chrome the browser fires `beforeinstallprompt`, which we stash in
/// web/index.html; [canInstall] then reports true and [promptInstall] shows the
/// native install dialog. iOS Safari has no such API, so [isIosSafari] lets the
/// UI fall back to a one-time "tap Share → Add to Home Screen" hint.
class PwaInstall {
  /// True when the browser has offered an installable event we can trigger.
  static bool get canInstall => impl.canInstall();

  /// Already running as an installed/standalone app.
  static bool get isStandalone => impl.isStandalone();

  /// iOS Safari, where install must be done manually via the Share menu.
  static bool get isIosSafari => impl.isIosSafari();

  /// Shows the native install prompt. Returns the outcome string
  /// ('accepted' / 'dismissed' / 'unavailable').
  static Future<String> promptInstall() => impl.promptInstall();

  /// Renames the installable app (home-screen label + PWA manifest name) at
  /// runtime — used so recipients install it under the baby's name instead of
  /// "Peekaboo". No-op off the web.
  static void setAppName(String name) => impl.setAppName(name);
}
