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

  /// 普通版：3000，概念版：3001
  int get port => isLite ? 3001 : 3000;
  String get baseUrl => 'http://127.0.0.1:$port';

  String _stdCookie = '';
  String _liteCookie = '';
  String get cookie => isLite ? _liteCookie : _stdCookie;
  bool get isGuest => cookie.isEmpty;

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    final m = sp.getString('mode') ?? 'standard';
    _mode = m == 'lite' ? KuGouMode.lite : KuGouMode.standard;
    _stdCookie = sp.getString('cookie_standard') ?? '';
    _liteCookie = sp.getString('cookie_lite') ?? '';
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
    if (isLite) {
      _liteCookie = c;
    } else {
      _stdCookie = c;
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setString(isLite ? 'cookie_lite' : 'cookie_standard', c);
    notifyListeners();
  }

  Future<void> clearCookie() async {
    if (isLite) {
      _liteCookie = '';
    } else {
      _stdCookie = '';
    }
    final sp = await SharedPreferences.getInstance();
    await sp.remove(isLite ? 'cookie_lite' : 'cookie_standard');
    notifyListeners();
  }
}
