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
  /// Where the PWA is hosted. On web we reuse the current origin so local
  /// testing "just works"; in production set this to your deployed domain.
  static String baseUrl = kIsWeb ? Uri.base.origin : 'https://peekaboo.app';

  static String linkFor(String token) => '$baseUrl/#/v/$token';

  static String _message(String token, String recipient) =>
      'A photo for $recipient 💛 Tap to view in Peekaboo:\n${linkFor(token)}';

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
