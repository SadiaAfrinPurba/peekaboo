import 'local_store_stub.dart'
    if (dart.library.js) 'local_store_web.dart' as impl;

/// Tiny persistent key/value store. On web it uses `window.localStorage`
/// (survives PWA restarts); on other platforms it's an in-memory fallback.
/// Used for the recipient's saved name and one-time UI flags.
String? getLocal(String key) => impl.getLocal(key);
void setLocal(String key, String value) => impl.setLocal(key, value);
