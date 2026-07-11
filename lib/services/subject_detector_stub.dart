import 'dart:typed_data';
import 'dart:ui';

/// Non-web fallback. Returns no regions until on-device ML Kit face detection
/// is wired for Android/iOS.
Future<List<Rect>> detectSubjects(Uint8List bytes) async => const <Rect>[];
