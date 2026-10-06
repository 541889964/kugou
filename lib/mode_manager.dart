import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum KuGouMode { standard, lite }

class ModeManager extends ChangeNotifier {
  static final ModeManager I = ModeManager._();
  ModeManager._();
  KuGouMode _mode = KuGouMode.standard;
  KuGouMode get mode => _mode;
  bool get isLite => _mode == KuGouMode.lite;
  String get modeId => isLite ? 'lite' : 'standard';
  String _std = '', _lite = '';
  String get cookie => isLite ? _lite : _std;
  bool get isGuest => cookie.isEmpty;

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    _mode = (sp.getString('mode') ?? 'standard') == 'lite'
        ? KuGouMode.lite : KuGouMode.standard;
    _std = sp.getString('cookie_standard') ?? '';
    _lite = sp.getString('cookie_lite') ?? '';
    notifyListeners();
  }

  Future<void> switchMode(KuGouMode m) async {
    _mode = m;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('mode', m == KuGouMode.lite ? 'lite' : 'standard');
    notifyListeners();
  }

  Future<void> setCookie(String c) async {
    c = c.trim();
    if (isLite) { _lite = c; } else { _std = c; }
    final sp = await SharedPreferences.getInstance();
    await sp.setString(isLite ? 'cookie_lite' : 'cookie_standard', c);
    notifyListeners();
  }

  Future<void> clearCookie() async {
    if (isLite) { _lite = ''; } else { _std = ''; }
    final sp = await SharedPreferences.getInstance();
    await sp.remove(isLite ? 'cookie_lite' : 'cookie_standard');
    notifyListeners();
  }
}
