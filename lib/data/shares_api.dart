import 'dart:ui';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of resolving a share token on the recipient side.
class SharedPhoto {
  final String recipientName;
  final String? imageUrl; // null when expired / already viewed once
  final bool viewOnce;
  final bool expired;
  final bool notFound;
  final List<Rect> subjectRects;

  const SharedPhoto({
    required this.recipientName,
    required this.imageUrl,
    required this.viewOnce,
    required this.expired,
    this.notFound = false,
    this.subjectRects = const [],
  });

  static const SharedPhoto missing = SharedPhoto(
    recipientName: '',
    imageUrl: null,
    viewOnce: false,
    expired: false,
    notFound: true,
  );
}

/// Resolves a share link via the SECURITY DEFINER `get_share` function. Works
/// for anonymous visitors — the token is the only credential. Returns exactly
/// one photo or nothing; other shares can't be listed or guessed.
Future<SharedPhoto> fetchShare(String token) async {
  final client = Supabase.instance.client;
  final rows = await client.rpc('get_share', params: {'p_token': token}) as List;
  if (rows.isEmpty) return SharedPhoto.missing;

  final r = rows.first as Map<String, dynamic>;
  return SharedPhoto(
    recipientName: (r['recipient_name'] as String?) ?? 'a loved one',
    imageUrl: r['image_url'] as String?,
    viewOnce: (r['view_once'] as bool?) ?? false,
    expired: (r['expired'] as bool?) ?? false,
    subjectRects: _parseRects(r['subject_rects']),
  );
}

List<Rect> _parseRects(dynamic raw) {
  if (raw is! List) return const [];
  final out = <Rect>[];
  for (final item in raw) {
    if (item is List && item.length == 4) {
      out.add(Rect.fromLTWH(
        (item[0] as num).toDouble(),
        (item[1] as num).toDouble(),
        (item[2] as num).toDouble(),
        (item[3] as num).toDouble(),
      ));
    }
  }
  return out;
}
