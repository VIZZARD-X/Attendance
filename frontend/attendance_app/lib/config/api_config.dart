class ApiConfig {
  // Local IP for physical phone testing on same Wi-Fi.
  static const String _localIp = 'http://10.127.123.219:8000/api/v1';

  // Compile-time overrides:
  // flutter run --dart-define=API_BASE_URL=https://your-backend.onrender.com/api/v1
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  // For Android Emulator
  static const String _androidEmulatorUrl = 'http://10.0.2.2:8000/api/v1';

  // For Local Tunnel (e.g. VS Code Port Forwarding, ngrok, localtunnel)
  // Ensure that 'Port Forwarding' is active in VS Code if using this method.
  static const String _localtunnelUrl = 'https://qdg6mx71-8000.inc1.devtunnels.ms/api/v1';

  // Change this to false to use local IP for debugging!
  static const bool isProduction = true;

  // Your Render URL
  static const String _productionUrl = 'https://presence-cne6ezafcncnduf3.indiasouthcentral-01.azurewebsites.net/api/v1';

  // Base URL resolution
  static String get baseUrl {
    if (isProduction) {
      return _productionUrl;
    }
    
    // Check if we're running on the web
    if (identical(0, 0.0)) { 
      // A trick to detect web without importing flutter/foundation.dart
      return 'http://127.0.0.1:8000/api/v1';
    }
    
    return _localtunnelUrl; // Fallback to localtunnel for physical device USB debugging
  }

  // Connection settings (90s to handle Render free-tier cold starts gracefully)
  static const Duration connectionTimeout = Duration(seconds: 90);
  static const Duration receiveTimeout = Duration(seconds: 90);
  
  // Auth endpoints
  static String login = '$baseUrl/auth/token/';
  static String register = '$baseUrl/auth/register/';
  static String me = '$baseUrl/auth/me/';
  static String tokenRefresh = '$baseUrl/auth/token/refresh/';
  
  // Headers
  static Map<String, String> get headers => {
    'Bypass-Tunnel-Reminder': 'true', // Required to bypass Localtunnel warning page
  };
  
  static Map<String, String> authHeaders(String? token) => {
    'Authorization': 'Bearer ${token ?? ""}',
    'Bypass-Tunnel-Reminder': 'true', // Required to bypass Localtunnel warning page
  };
}
