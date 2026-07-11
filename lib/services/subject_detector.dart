import 'dart:typed_data';
import 'dart:ui';

import 'subject_detector_stub.dart'
    if (dart.library.js) 'subject_detector_web.dart' as impl;

/// Detects subject (face) regions in an image, returned as rectangles
/// normalized to 0..1 in image space.
///
/// - Web: runs TensorFlow.js BlazeFace in the browser (see web/index.html).
/// - Mobile: currently a stub returning []; wire ML Kit face detection here.
///
/// Always safe: returns [] when detection is unavailable, so the watermark
/// simply falls back to full coverage.
Future<List<Rect>> detectSubjects(Uint8List bytes) => impl.detectSubjects(bytes);
