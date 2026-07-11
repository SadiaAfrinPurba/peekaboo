import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/photo.dart';
import '../models/share_link.dart';
import '../services/subject_detector.dart';

/// Backend-backed store for the signed-in owner's photos and share links.
/// Talks to Supabase: private Storage bucket + `photos`/`shares` tables guarded
/// by Row-Level Security (see `supabase/schema.sql`).
class Vault extends ChangeNotifier {
  final SupabaseClient _db = Supabase.instance.client;
  final Random _rng = Random.secure();

  List<Photo> _photos = [];
  bool loading = true;
  String? error;

  List<Photo> get photos => List.unmodifiable(_photos);

  String get _uid => _db.auth.currentUser!.id;

  /// Signed URLs are valid for an hour — long enough to browse, short enough to
  /// not linger.
  static const int _viewUrlTtl = 60 * 60;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    if (_db.auth.currentUser == null) {
      error = 'Sign-in unavailable — enable "Anonymous sign-ins" in Supabase → '
          'Authentication → Providers, then reload.';
      loading = false;
      notifyListeners();
      return;
    }

    try {
      final rows = await _db
          .from('photos')
          .select()
          .order('created_at', ascending: false);

      final list = <Photo>[];
      for (final r in rows) {
        final path = r['storage_path'] as String;
        final url = await _db.storage
            .from(SupabaseConfig.photosBucket)
            .createSignedUrl(path, _viewUrlTtl);
        list.add(Photo(
          id: r['id'] as String,
          caption: (r['caption'] as String?) ?? '',
          addedAt: DateTime.parse(r['created_at'] as String),
          storagePath: path,
          imageUrl: url,
          subjectRects: _parseRects(r['subject_rects']),
        ));
      }
      _photos = list;
    } catch (e) {
      error = _friendly(e);
    }
    loading = false;
    notifyListeners();
  }

  Future<void> addPhoto(Uint8List bytes, String caption) async {
    final id = _id(12);
    final path = '$_uid/$id.jpg';

    // Detect faces on-device so the watermark can leave them clear.
    final rects = await detectSubjects(bytes);

    await _db.storage.from(SupabaseConfig.photosBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    await _db.from('photos').insert({
      'id': id,
      'owner_id': _uid,
      'caption': caption.trim(),
      'storage_path': path,
      'subject_rects': _rectsToJson(rects),
    });

    _photos.insert(
      0,
      Photo(
        id: id,
        caption: caption.trim(),
        addedAt: DateTime.now(),
        storagePath: path,
        bytes: bytes, // render instantly from memory
        subjectRects: rects,
      ),
    );
    notifyListeners();
  }

  Future<void> removePhoto(Photo photo) async {
    await _db.storage
        .from(SupabaseConfig.photosBucket)
        .remove([photo.storagePath]);
    await _db.from('photos').delete().eq('id', photo.id);
    _photos.removeWhere((p) => p.id == photo.id);
    notifyListeners();
  }

  /// Mints a per-recipient link. The image is exposed only through a signed URL
  /// that expires with the share, stored server-side and handed out by the
  /// token-gated `get_share` function.
  Future<ShareLink> createShare(
    Photo photo,
    String recipientName, {
    bool viewOnce = false,
    Duration expiresIn = const Duration(days: 7),
  }) async {
    final token = _id(22);
    final signedUrl = await _db.storage
        .from(SupabaseConfig.photosBucket)
        .createSignedUrl(photo.storagePath, expiresIn.inSeconds);
    final expiresAt = DateTime.now().add(expiresIn);
    final recipient =
        recipientName.trim().isEmpty ? 'a loved one' : recipientName.trim();

    await _db.from('shares').insert({
      'token': token,
      'photo_id': photo.id,
      'owner_id': _uid,
      'recipient_name': recipient,
      'signed_url': signedUrl,
      'view_once': viewOnce,
      'expires_at': expiresAt.toIso8601String(),
    });

    return ShareLink(
      token: token,
      photoId: photo.id,
      recipientName: recipient,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      viewOnce: viewOnce,
    );
  }

  List<List<double>> _rectsToJson(List<Rect> rects) => rects
      .map((r) => [r.left, r.top, r.width, r.height])
      .toList(growable: false);

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

  static const _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  String _id(int length) => List.generate(
        length,
        (_) => _alphabet[_rng.nextInt(_alphabet.length)],
      ).join();

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('row-level security') || s.contains('violates')) {
      return 'Permission error — did you run supabase/schema.sql?';
    }
    return 'Something went wrong: $s';
  }
}
