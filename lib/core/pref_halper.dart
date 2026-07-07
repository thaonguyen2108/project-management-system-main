import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class PrefHelper {
  static SharedPreferences? _prefs;

  // Khởi tạo (Gọi ở hàm main)
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Lưu trạng thái đăng nhập (Set)
  static Future<void> setIsLoggedIn(bool value) async {
    await _prefs?.setBool('is_login', value);
  }

  // Đọc trạng thái đăng nhập (Get) - Mặc định là false nếu chưa có
  static bool get isLoggedIn => _prefs?.getBool('is_login') ?? false;

  // ========================================================================
  // Lưu tên người dùng
  static Future<void> setUserName(String name) async {
    await _prefs?.setString('user_name', name);
  }

  // Đọc tên người dùng
  static String? get userName => _prefs?.getString('user_name');

  // ========================================================================
  // Lưu trạng thái dark mode (Set)
  static Future<void> setIsDarkMode(bool value) async {
    await _prefs?.setBool('is_darkMode', value);
  }

  // Đọc trạng thái dark mode (Get) - Mặc định là false nếu chưa có
  static bool get isDarkMode => _prefs?.getBool('is_darkMode') ?? false;

  static Future<void> setThemeMode(String value) async {
    await _prefs?.setString('theme_mode', value);
  }

  static String get themeMode => _prefs?.getString('theme_mode') ?? 'system';

  static String getUiPreference(String? uid, String key, String fallback) {
    final normalizedUid = uid?.trim();
    if (normalizedUid == null || normalizedUid.isEmpty) return fallback;
    return _prefs?.getString('ui_${normalizedUid}_$key') ?? fallback;
  }

  static Future<void> setUiPreference(
    String? uid,
    String key,
    String value,
  ) async {
    final normalizedUid = uid?.trim();
    if (normalizedUid == null || normalizedUid.isEmpty) return;
    await _prefs?.setString('ui_${normalizedUid}_$key', value);
  }

  // ========================================================================
  // Lưu mã màu chủ đạo
  static Future<void> saveColor(Color color) async {
    await _prefs?.setInt('my_theme_color', color.value);
  }

  // Đọc màu chủ đạo
  static Color get themeColor {
    int? val = _prefs?.getInt('my_theme_color');
    // Nếu chưa có màu nào lưu trong máy, mặc định trả về màu Trắng (255, 255, 255, 255)
    return val != null ? Color(val) : const Color.fromARGB(255, 12, 0, 78);
  }

  // ========================================================================
  // Xóa sạch (Dùng khi Đăng xuất)
  static Future<void> logout() async {
    await _prefs?.clear();
  }
}
