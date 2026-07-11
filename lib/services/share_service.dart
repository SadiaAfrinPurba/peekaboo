import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Builds the tokenized view link and hands it to messaging apps.
///
/// The whole security model rests on one idea: we share a LINK, never a file.
/// Messaging apps (WhatsApp/Messenger/IG DM) happily carry links, but a
/// Facebook/TikTok/Instagram feed or story composer has no way to turn a link
/// into a post — so those paths are closed by construction.
class ShareService {
  /// Where the PWA is hosted. On web we reuse the page's own URL (origin +
  /// base-href path, e.g. `/peekaboo/`) so links point back to the app no
  /// matter where it's deployed — localhost, a project subpath, or a custom
  /// domain. We strip any `#…` route fragment to get the clean app base.
  static String get baseUrl {
    if (!kIsWeb) return 'https://peekaboo.app';
    final full = Uri.base.toString();
    final hash = full.indexOf('#');
    final base = hash >= 0 ? full.substring(0, hash) : full;
    // Drop a trailing slash so linkFor can add exactly one.
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  static String linkFor(String token) => '$baseUrl/#/v/$token';

  /// The permanent family-gallery link — same URL for every recipient.
  static String galleryLinkFor(String token) => '$baseUrl/#/g/$token';

  static String _message(String token, String recipient) =>
      'A photo for $recipient 💛 Tap to view in Peekaboo:\n${linkFor(token)}';

  static String _galleryMessage(String token, String babyName) {
    final who = babyName.trim().isEmpty ? 'our little one' : babyName.trim();
    return 'Photos of $who 💛 Tap to open the private gallery in Peekaboo:\n'
        '${galleryLinkFor(token)}';
  }

  /// Opens WhatsApp with the family-gallery link pre-filled.
  static Future<bool> shareGalleryToWhatsApp(String token, String babyName) {
    final url = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(_galleryMessage(token, babyName))}',
    );
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }

  /// Opens Telegram's share dialog for the family-gallery link.
  static Future<bool> shareGalleryToTelegram(String token, String babyName) {
    final url = Uri.parse(
      'https://t.me/share/url?url=${Uri.encodeComponent(galleryLinkFor(token))}'
      '&text=${Uri.encodeComponent(_galleryMessage(token, babyName).split('\n').first)}',
    );
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }

  /// OS share sheet for the family-gallery link (Messenger, Instagram DM, …).
  static Future<void> shareGalleryViaSystem(String token, String babyName) {
    return Share.share(
      _galleryMessage(token, babyName),
      subject: 'Peekaboo — private photo gallery',
    );
  }

  /// Opens WhatsApp with the link pre-filled (works on web and mobile).
  static Future<bool> shareToWhatsApp(String token, String recipient) {
    final url = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(_message(token, recipient))}',
    );
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }

  /// Opens Telegram's share dialog (reliable prefilled deep link).
  static Future<bool> shareToTelegram(String token, String recipient) {
    final url = Uri.parse(
      'https://t.me/share/url?url=${Uri.encodeComponent(linkFor(token))}'
      '&text=${Uri.encodeComponent('A photo for $recipient 💛')}',
    );
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }

  /// Falls back to the OS share sheet — the user picks Messenger, Instagram
  /// DM, etc. (Instagram has no prefilled-DM URL scheme, so DM sharing always
  /// goes through here or a manual paste.)
  static Future<void> shareViaSystem(String token, String recipient) {
    return Share.share(
      _message(token, recipient),
      subject: 'A Peekaboo photo for $recipient',
    );
  }
}
