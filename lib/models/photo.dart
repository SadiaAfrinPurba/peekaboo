import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// A protected photo owned by the signed-in user.
///
/// The image is stored in a private Supabase bucket. For display we use a
/// short-lived signed [imageUrl]; freshly-added photos also keep [bytes] in
/// memory so they render instantly without a round-trip. Either way the raw
/// file is never handed to the OS or another app.
class Photo {
  final String id;
  final String caption;
  final DateTime addedAt;

  /// When the photo was taken — drives the timeline and age label. May differ
  /// from [addedAt] (upload time) for backfilled photos. Falls back to
  /// [addedAt] via [date] when not set.
  final DateTime? takenAt;

  final String storagePath;
  final String? imageUrl;
  final Uint8List? bytes;

  /// Face/subject regions to keep watermark-free, normalized 0..1 in image
  /// space (left, top, width, height).
  final List<Rect> subjectRects;

  const Photo({
    required this.id,
    required this.caption,
    required this.addedAt,
    required this.storagePath,
    this.takenAt,
    this.imageUrl,
    this.bytes,
    this.subjectRects = const [],
  });

  /// The date to place this photo on the timeline / compute age from.
  DateTime get date => takenAt ?? addedAt;

  /// Best available image source: in-memory bytes if we have them, else the
  /// signed network URL.
  ImageProvider get imageProvider {
    if (bytes != null) return MemoryImage(bytes!);
    return NetworkImage(imageUrl!);
  }

  Photo copyWith({
    DateTime? takenAt,
    String? imageUrl,
    Uint8List? bytes,
    List<Rect>? subjectRects,
  }) =>
      Photo(
        id: id,
        caption: caption,
        addedAt: addedAt,
        takenAt: takenAt ?? this.takenAt,
        storagePath: storagePath,
        imageUrl: imageUrl ?? this.imageUrl,
        bytes: bytes ?? this.bytes,
        subjectRects: subjectRects ?? this.subjectRects,
      );
}
