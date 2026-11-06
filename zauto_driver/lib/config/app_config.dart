class AppConfig {
  // Production API served through Cloudflare Tunnel.
  // Override at build time for local development:
  // flutter run --dart-define=BACKEND_URL=http://192.168.0.100:3000
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://api.zchatauto.io.vn',
  );

  // Keep WebSocket on the same origin as the REST API.
  static String get websocketUrl {
    final uri = Uri.parse(backendUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri.replace(scheme: scheme, path: '/ws', query: '', fragment: '').toString();
  }
}
