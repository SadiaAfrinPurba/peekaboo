import 'dart:ui';

import 'package:supabase_flutter/supabase_flutter.dart';

/// One photo as seen by a gallery recipient (no owner-only fields).
class GalleryPhoto {
  final String id;
  final String caption;
  final DateTime takenAt;
  final String imageUrl;
  final List<Rect> subjectRects;

  const GalleryPhoto({
    required this.id,
    required this.caption,
    required this.takenAt,
    required this.imageUrl,
    this.subjectRects = const [],
  });
}

/// Result of resolving a family-gallery token on the recipient side.
class GalleryFeed {
  final bool found;
  final bool active;
  final String babyName;
  final DateTime? birthdate;
  final List<GalleryPhoto> photos;

  const GalleryFeed({
    required this.found,
    required this.active,
    this.babyName = '',
    this.birthdate,
    this.photos = const [],
  });

  static const GalleryFeed missing =
      GalleryFeed(found: false, active: false);
}

/// Resolves a family-gallery link via the SECURITY DEFINER `get_gallery`
/// function. Works for anonymous visitors — the token is the only credential.
Future<GalleryFeed> fetchGallery(String token) async {
  final client = Supabase.instance.client;
  final res = await client.rpc('get_gallery', params: {'p_token': token});
  if (res is! Map) return GalleryFeed.missing;
  final map = res.cast<String, dynamic>();

  if (map['found'] != true) return GalleryFeed.missing;
  final active = map['active'] == true;
  final babyName = (map['baby_name'] as String?)?.trim() ?? '';
  if (!active) {
    return GalleryFeed(found: true, active: false, babyName: babyName);
  }

  final birthdate = _parseDate(map['birthdate']);
  final rawPhotos = (map['photos'] as List?) ?? const [];
  final photos = <GalleryPhoto>[];
  for (final item in rawPhotos) {
    if (item is! Map) continue;
    final m = item.cast<String, dynamic>();
    final url = m['image_url'] as String?;
    if (url == null || url.isEmpty) continue;
    photos.add(GalleryPhoto(
      id: (m['id'] as String?) ?? '',
      caption: (m['caption'] as String?) ?? '',
      takenAt: _parseDate(m['taken_at']) ?? DateTime.now(),
      imageUrl: url,
      subjectRects: _parseRects(m['subject_rects']),
    ));
  }

  return GalleryFeed(
    found: true,
    active: true,
    babyName: babyName,
    birthdate: birthdate,
    photos: photos,
  );
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString())?.toLocal();
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
