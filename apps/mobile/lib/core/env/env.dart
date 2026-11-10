class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const apiUrl = String.fromEnvironment('API_URL');

  static bool get configurado =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty && apiUrl.isNotEmpty;

  static String get apiBaseUrl {
    final sinBarra = apiUrl.replaceAll(RegExp(r'/+$'), '');
    return sinBarra.endsWith('/api/v1') ? sinBarra : '$sinBarra/api/v1';
  }
}
