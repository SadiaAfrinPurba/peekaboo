// Non-web fallback: in-memory only (persists for the session). Recipients use
// the web PWA, where local_store_web.dart provides real persistence.
final Map<String, String> _mem = {};

String? getLocal(String key) => _mem[key];
void setLocal(String key, String value) => _mem[key] = value;
