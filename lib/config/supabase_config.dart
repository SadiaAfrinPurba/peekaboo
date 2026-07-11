/// Supabase connection settings.
///
/// The publishable/anon key is a PUBLIC key — safe to ship in the client. All
/// real protection comes from Row-Level Security policies in the database
/// (see `supabase/schema.sql`). Never put the `service_role`/secret key here.
class SupabaseConfig {
  static const String url = 'https://gwrjdahellerrbsojtjw.supabase.co';

  static const String publishableKey =
      'sb_publishable_QBhTOAgv7gTMkDJN2hK4ZQ_0c0XKhSh';

  static const String photosBucket = 'photos';
}
