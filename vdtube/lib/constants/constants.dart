import 'package:logger/logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class Constants {
  static const String baseUrl = 'https://backendproject-qo5y.onrender.com/api/v1';
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
  static Future<String?> deleteAccessToken() async {
    return await secureStorage.read(key: 'accessToken');
  }
  // Delete Refresh Token
  static Future<String?> deleteRefreshToken() async {
    return await secureStorage.read(key: 'refreshToken');
  }


}