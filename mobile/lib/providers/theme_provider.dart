import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode mode = ThemeMode.system;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    mode = {'light': ThemeMode.light, 'dark': ThemeMode.dark}[p.getString('theme_mode')] ?? ThemeMode.system;
  }

  Future<void> set(ThemeMode m) async {
    mode = m;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('theme_mode', m == ThemeMode.light ? 'light' : m == ThemeMode.dark ? 'dark' : 'system');
  }
}
