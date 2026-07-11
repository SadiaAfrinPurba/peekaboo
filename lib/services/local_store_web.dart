// Web implementation backed by window.localStorage (persists across sessions
// and PWA restarts).
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String? getLocal(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void setLocal(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {
    // Storage can be unavailable in private mode — degrade silently.
  }
}
