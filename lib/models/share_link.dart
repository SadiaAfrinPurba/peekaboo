/// A per-recipient share token. In production this row lives in your backend
/// (e.g. a Supabase `shares` table) and the token maps to a short-lived signed
/// URL. The recipient's name is baked in so it can be stamped as a watermark,
/// making every leaked screenshot traceable to exactly one person.
class ShareLink {
  final String token;
  final String photoId;
  final String recipientName;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool viewOnce;
  bool viewed;

  ShareLink({
    required this.token,
    required this.photoId,
    required this.recipientName,
    required this.createdAt,
    this.expiresAt,
    this.viewOnce = false,
    this.viewed = false,
  });

  bool get isExpired {
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return true;
    if (viewOnce && viewed) return true;
    return false;
  }
}
