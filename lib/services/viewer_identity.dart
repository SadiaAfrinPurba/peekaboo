import 'local_store.dart';

/// The recipient's self-chosen name, remembered on their device so the
/// watermark can tag who's viewing. Asked once, on first open of a gallery.
class ViewerIdentity {
  static const _key = 'peekaboo_viewer_name';

  static String? get name {
    final v = getLocal(_key)?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  static bool get isSet => name != null;

  static void save(String value) {
    final v = value.trim();
    if (v.isNotEmpty) setLocal(_key, v);
  }
}
