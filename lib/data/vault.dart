import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/family_gallery.dart';
import '../models/photo.dart';
import '../models/share_link.dart';
import '../services/subject_detector.dart';

/// Backend-backed store for the signed-in owner's photos and share links.
/// Talks to Supabase: private Storage bucket + `photos`/`shares`/`galleries`
/// tables guarded by Row-Level Security (see `supabase/schema.sql`).
class Vault extends ChangeNotifier {
  final SupabaseClient _db = Supabase.instance.client;
  final Random _rng = Random.secure();

  List<Photo> _photos = [];
  bool loading = true;
  String? error;

  /// The owner's single permanent family-gallery link (created on first load).
  FamilyGallery? gallery;

  List<Photo> get photos => List.unmodifiable(_photos);

  String get _uid => _db.auth.currentUser!.id;

  /// Stored signed URLs are minted for a year so the family link keeps working
  /// without a login; we refresh any that fall inside [_refreshBefore] of
  /// expiry whenever the owner opens the app.
  static const int _signedUrlTtl = 60 * 60 * 24 * 365; // 1 year
  static const Duration _refreshBefore = Duration(days: 30);

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
      await _loadGallery();

      final rows = await _db
          .from('photos')
          .select()
          .order('taken_at', ascending: false);

      final list = <Photo>[];
      for (final r in rows) {
        final path = r['storage_path'] as String;
        final url = await _ensureSignedUrl(
          id: r['id'] as String,
          path: path,
          storedUrl: r['signed_url'] as String?,
          storedExpires: _parseTs(r['signed_url_expires']),
        );
        list.add(Photo(
          id: r['id'] as String,
          caption: (r['caption'] as String?) ?? '',
          addedAt: DateTime.parse(r['created_at'] as String),
          takenAt: _parseTs(r['taken_at']),
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

  /// Loads the owner's family gallery, creating it (with a fresh token) the
  /// first time. Guarantees [gallery] is non-null on success.
  Future<void> _loadGallery() async {
    final rows =
        await _db.from('galleries').select().eq('owner_id', _uid).limit(1);
    if (rows.isEmpty) {
      final token = _id(24);
      await _db.from('galleries').insert({
        'owner_id': _uid,
        'token': token,
        'active': true,
      });
      gallery = FamilyGallery(token: token);
    } else {
      final r = rows.first;
      gallery = FamilyGallery(
        token: r['token'] as String,
        babyName: (r['baby_name'] as String?) ?? '',
        birthdate: _parseDate(r['birthdate']),
        active: (r['active'] as bool?) ?? true,
      );
    }
  }

  /// Returns a valid signed URL for [path], refreshing (and persisting) it when
  /// the stored one is missing or close to expiring.
  Future<String> _ensureSignedUrl({
    required String id,
    required String path,
    required String? storedUrl,
    required DateTime? storedExpires,
  }) async {
    final fresh = storedUrl != null &&
        storedExpires != null &&
        storedExpires.isAfter(DateTime.now().add(_refreshBefore));
    if (fresh) return storedUrl;

    final url = await _db.storage
        .from(SupabaseConfig.photosBucket)
        .createSignedUrl(path, _signedUrlTtl);
    final expires = DateTime.now().add(const Duration(seconds: _signedUrlTtl));
    await _db.from('photos').update({
      'signed_url': url,
      'signed_url_expires': expires.toIso8601String(),
    }).eq('id', id);
    return url;
  }

  Future<void> addPhoto(
    Uint8List bytes,
    String caption, {
    DateTime? takenAt,
  }) async {
    final id = _id(12);
    final path = '$_uid/$id.jpg';
    final taken = takenAt ?? DateTime.now();

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

    // Mint a long-lived signed URL up front so the photo is instantly visible
    // through the family gallery link.
    final signedUrl = await _db.storage
        .from(SupabaseConfig.photosBucket)
        .createSignedUrl(path, _signedUrlTtl);
    final signedExpires =
        DateTime.now().add(const Duration(seconds: _signedUrlTtl));

    await _db.from('photos').insert({
      'id': id,
      'owner_id': _uid,
      'caption': caption.trim(),
      'storage_path': path,
      'taken_at': taken.toIso8601String(),
      'subject_rects': _rectsToJson(rects),
      'signed_url': signedUrl,
      'signed_url_expires': signedExpires.toIso8601String(),
    });

    final photo = Photo(
      id: id,
      caption: caption.trim(),
      addedAt: DateTime.now(),
      takenAt: taken,
      storagePath: path,
      imageUrl: signedUrl,
      bytes: bytes, // render instantly from memory
      subjectRects: rects,
    );
    // Insert keeping the newest-taken-first ordering.
    final idx = _photos.indexWhere((p) => p.date.isBefore(photo.date));
    _photos.insert(idx < 0 ? _photos.length : idx, photo);
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

  /// Updates the baby's name and/or birthdate on the family gallery (used for
  /// the gallery header and per-photo age labels).
  Future<void> setBabyProfile({String? name, DateTime? birthdate}) async {
    final g = gallery;
    if (g == null) return;
    final update = <String, dynamic>{};
    if (name != null) update['baby_name'] = name.trim();
    if (birthdate != null) update['birthdate'] = _dateOnly(birthdate);
    if (update.isEmpty) return;
    await _db.from('galleries').update(update).eq('owner_id', _uid);
    gallery = g.copyWith(
      babyName: name ?? g.babyName,
      birthdate: birthdate ?? g.birthdate,
    );
    notifyListeners();
  }

  /// Enables or revokes the family gallery link.
  Future<void> setGalleryActive(bool active) async {
    final g = gallery;
    if (g == null) return;
    await _db.from('galleries').update({'active': active}).eq('owner_id', _uid);
    gallery = g.copyWith(active: active);
    notifyListeners();
  }

  /// Mints a per-recipient single-photo link (the older one-off share flow).
  /// The image is exposed only through a signed URL that expires with the
  /// share, handed out by the token-gated `get_share` function.
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

  DateTime? _parseTs(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

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
    if (s.contains('column') && s.contains('does not exist')) {
      return 'Your database is missing new columns — re-run supabase/schema.sql.';
    }
    return 'Something went wrong: $s';
  }
}
