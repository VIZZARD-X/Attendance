class ApiConfig {
  // Local IP for physical phone testing on same Wi-Fi.
  static const String _localIp = 'http://10.201.14.219:8000/api/v1';

  // Compile-time overrides:
  // flutter run --dart-define=API_BASE_URL=https://your-backend.onrender.com/api/v1
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  // For Android Emulator
  static const String _androidEmulatorUrl = 'http://10.0.2.2:8000/api/v1';

  // For Local Tunnel (e.g. VS Code Port Forwarding, ngrok, localtunnel)
  // Ensure that 'Port Forwarding' is active in VS Code if using this method.
  static const String _localtunnelUrl = 'https://qdg6mx71-8000.inc1.devtunnels.ms/api/v1';

  // Getter for base URL depending on platform
  static String get baseUrl {
    // if (kIsWeb) return _webUrl;
    return _localtunnelUrl; // Make sure to use the active local tunnel URL
  }
  
  // Connection settings
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Auth endpoints
  static String login = '$baseUrl/auth/token/';
  static String register = '$baseUrl/auth/register/';
  static String me = '$baseUrl/auth/me/';
  static String tokenRefresh = '$baseUrl/auth/token/refresh/';
  
  // Headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Bypass-Tunnel-Reminder': 'true', // Required to bypass Localtunnel warning page
  };
  
  static Map<String, String> authHeaders(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
    'Bypass-Tunnel-Reminder': 'true', // Required to bypass Localtunnel warning page
  };
}
