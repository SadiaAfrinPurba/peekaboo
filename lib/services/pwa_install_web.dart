// Web PWA install bridge. The heavy lifting (capturing beforeinstallprompt) is
// done by the small script in web/index.html; here we just read/trigger it.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;

bool canInstall() {
  try {
    return js_util.getProperty(html.window, 'peekabooDeferredPrompt') != null;
  } catch (_) {
    return false;
  }
}

bool isStandalone() {
  try {
    final fn = js_util.getProperty(html.window, 'peekabooIsStandalone');
    if (fn == null) return false;
    final r = js_util.callMethod(html.window, 'peekabooIsStandalone', const []);
    return r == true;
  } catch (_) {
    return false;
  }
}

bool isIosSafari() {
  try {
    final ua = html.window.navigator.userAgent.toLowerCase();
    final isIos = ua.contains('iphone') ||
        ua.contains('ipad') ||
        ua.contains('ipod') ||
        // iPadOS 13+ reports as Mac; detect touch to disambiguate.
        (ua.contains('macintosh') &&
            (html.window.navigator.maxTouchPoints ?? 0) > 1);
    final isSafari = ua.contains('safari') &&
        !ua.contains('crios') && // Chrome on iOS
        !ua.contains('fxios'); // Firefox on iOS
    return isIos && isSafari;
  } catch (_) {
    return false;
  }
}

Future<String> promptInstall() async {
  try {
    final promise =
        js_util.callMethod(html.window, 'peekabooPromptInstall', const []);
    final result = await js_util.promiseToFuture<dynamic>(promise);
    return result?.toString() ?? 'done';
  } catch (_) {
    return 'unavailable';
  }
}
