import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fishinsight/database/database_helper.dart';

/// 闲鱼账号管理服务
///
/// 安全设计：
/// - 永远不存储用户密码（登录全程由淘宝官方 WebView 完成）
/// - 仅保存登录后的会话状态元数据（昵称、登录时间）
/// - Cookie 由 WebView 内核自行管理，持久化于 App 沙盒内
/// - 敏感数据使用 flutter_secure_storage（底层 Android Keystore 硬件加密）
class XianyuAccountService {
  final DatabaseHelper db;

  XianyuAccountService(this.db);

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // —————— 安全存储 Key ——————
  static const _keyLoggedIn = 'xianyu_logged_in';
  static const _keyNickname = 'xianyu_nickname';
  static const _keyLoginTime = 'xianyu_login_time';

  // —————— 淘宝 / 闲鱼 域名常量 ——————
  /// 淘宝移动端登录入口（用户在 WebView 中操作，知鱼不碰密码）
  static const loginUrl =
      'https://login.m.taobao.com/login.htm?redirectURL=https%3A%2F%2Fwww.goofish.com';

  /// 闲鱼网页版（登录后用 Cookie 加载）
  static const goofishHomeUrl = 'https://www.goofish.com';

  /// 登录成功后的重定向目标域名（用于检测登录是否完成）
  static const _loginSuccessHosts = [
    'www.goofish.com',
    'goofish.com',
    'h5.m.goofish.com',
    'm.taobao.com',
    'www.taobao.com',
    'main.m.taobao.com',
  ];

  /// 登录页域名（用于判断是否仍在登录流程中）
  static const _loginHosts = [
    'login.m.taobao.com',
    'login.taobao.com',
  ];

  // —————— 登录状态检测 ——————

  /// 检查是否处于已登录状态
  Future<bool> isLoggedIn() async {
    final val = await _storage.read(key: _keyLoggedIn);
    return val == 'true';
  }

  /// 判断 URL 是否表示登录成功（已跳转离开登录页）
  bool isLoginSuccessUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return _loginSuccessHosts.contains(uri.host);
    } catch (_) {
      return false;
    }
  }

  /// 判断 URL 是否仍在登录页
  bool isOnLoginPage(String url) {
    try {
      final uri = Uri.parse(url);
      return _loginHosts.contains(uri.host);
    } catch (_) {
      return false;
    }
  }

  // —————— 登录成功处理 ——————

  /// 登录成功后保存状态（由 LoginPage 在检测到跳转后调用）
  Future<void> onLoginSuccess({String nickname = '闲鱼用户'}) async {
    final now = DateTime.now();
    await _storage.write(key: _keyLoggedIn, value: 'true');
    await _storage.write(
        key: _keyNickname, value: nickname.isNotEmpty ? nickname : '闲鱼用户');
    await _storage.write(key: _keyLoginTime, value: now.toIso8601String());
    await db.setSetting('xianyu_connected', 'true');
    await db.setSetting('xianyu_login_time', now.toString().substring(0, 16));
  }

  // —————— 账号信息读取 ——————

  /// 获取登录昵称
  Future<String> getNickname() async {
    return await _storage.read(key: _keyNickname) ?? '';
  }

  /// 获取登录时间（格式化）
  Future<String> getLoginTimeFormatted() async {
    final raw = await _storage.read(key: _keyLoginTime);
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.month}月${dt.day}日 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  /// 获取上次同步时间
  String getLastSyncTime() {
    return db.getSetting('last_sync_time', defaultValue: '');
  }

  // —————— 退出登录 ——————

  /// 退出登录：清除安全存储 + WebView Cookie + 数据库标记
  Future<void> logout() async {
    // 清除加密存储的登录元数据
    await _storage.delete(key: _keyLoggedIn);
    await _storage.delete(key: _keyNickname);
    await _storage.delete(key: _keyLoginTime);

    // 清除数据库中的连接标记
    await db.setSetting('xianyu_connected', 'false');

    // 清除 WebView Cookie（这会断掉淘宝/闲鱼的登录态）
    await WebViewCookieManager().clearCookies();
  }
}
