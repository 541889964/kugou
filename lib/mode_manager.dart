import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum KuGouMode { standard, lite }

class ModeManager extends ChangeNotifier {
  static final ModeManager I = ModeManager._();
  ModeManager._();
  KuGouMode _m = KuGouMode.lite;
  KuGouMode get mode => _m;
  bool get isLite => _m == KuGouMode.lite;

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    _m = (sp.getString('mode') ?? 'lite') == 'standard'
        ? KuGouMode.standard : KuGouMode.lite;
    notifyListeners();
  }

  Future<void> switchMode(KuGouMode m) async {
    _m = m;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('mode', m == KuGouMode.lite ? 'lite' : 'standard');
    notifyListeners();
  }
}
