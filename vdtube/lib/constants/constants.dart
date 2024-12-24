import 'package:logger/logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Constants {
  static const String baseUrl = 'https://vdtube.vercel.app/api/v1';
  static const String baseUrlForUploads =
      'https://backendproject-qo5y.onrender.com/api/v1';
  static var logger = Logger(
    printer: PrettyPrinter(),
  );
  static FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  // Fetch Access Token
  static Future<String?> getAccessToken() async {
    return await secureStorage.read(key: 'accessToken');
  }

  // Fetch Refresh Token
  static Future<String?> getRefreshToken() async {
    return await secureStorage.read(key: 'refreshToken');
  }

  // Delete Acceses Token
  static Future<void> deleteAccessToken() async {
    await secureStorage.delete(key: 'accessToken');
  }

  // Delete Refresh Token
  static Future<void> deleteRefreshToken() async {
    await secureStorage.delete(key: 'refreshToken');
  }

  static Future<String?> getUsername() async {
    return await secureStorage.read(key: 'username');
  }

  static Future<String?> getUserId() async {
    return await secureStorage.read(key: 'userId');
  }

  static Future<void> deleteAll() async {
    await secureStorage.deleteAll();
  }
}
