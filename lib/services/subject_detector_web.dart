// This file is only ever imported on web (via conditional import).
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'dart:ui';

/// Web face detection via the `peekabooDetectFaces` helper (BlazeFace) defined
/// in web/index.html. Returns face boxes normalized to 0..1 in image space.
Future<List<Rect>> detectSubjects(Uint8List bytes) async {
  final fn = js_util.getProperty(html.window, 'peekabooDetectFaces');
  if (fn == null) return const <Rect>[];

  final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
  try {
    final promise =
        js_util.callMethod(html.window, 'peekabooDetectFaces', [dataUrl]);
    final result = await js_util.promiseToFuture<dynamic>(promise);
    if (result == null) return const <Rect>[];

    final length = (js_util.getProperty(result, 'length') as num).toInt();
    final rects = <Rect>[];
    for (var i = 0; i < length; i++) {
      final o = js_util.getProperty(result, i);
      final x = (js_util.getProperty(o, 'x') as num).toDouble();
      final y = (js_util.getProperty(o, 'y') as num).toDouble();
      final w = (js_util.getProperty(o, 'w') as num).toDouble();
      final h = (js_util.getProperty(o, 'h') as num).toDouble();
      rects.add(Rect.fromLTWH(x, y, w, h));
    }
    return rects;
  } catch (_) {
    return const <Rect>[];
  }
}
