import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fishinsight/database/database_helper.dart';
import 'package:fishinsight/design/app_theme.dart';
import 'package:fishinsight/service/xianyu_account_service.dart';

/// 闲鱼账号登录页
///
/// 安全设计：
/// - 加载淘宝官方移动端登录页，用户自行输入账号密码
/// - 知鱼代码完全不经手密码，密码直接发给阿里服务器
/// - 登录成功后只记录会话状态，Cookie 由 WebView 内核管理
class XianyuLoginPage extends StatefulWidget {
  const XianyuLoginPage({super.key});

  @override
  State<XianyuLoginPage> createState() => _XianyuLoginPageState();
}

class _XianyuLoginPageState extends State<XianyuLoginPage> {
  DatabaseHelper get _db => Get.find<DatabaseHelper>();
  late final XianyuAccountService _accountService;
  late final WebViewController _controller;

  bool _isLoadingPage = true;
  bool _loginDetected = false;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _accountService = XianyuAccountService(_db);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _isLoadingPage = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() {
              _isLoadingPage = false;
              _currentUrl = url;
            });
            // 检测是否已离开登录页（表示登录成功）
            _checkLoginSuccess(url);
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      // 加载淘宝官方登录页，登录成功后自动跳转到闲鱼
      ..loadRequest(Uri.parse(XianyuAccountService.loginUrl));
  }

  /// 检测登录是否成功（URL 从 login.taobao.com 跳转到其他页面）
  Future<void> _checkLoginSuccess(String url) async {
    if (_loginDetected) return;

    if (_accountService.isLoginSuccessUrl(url)) {
      _loginDetected = true;

      // 尝试从页面提取用户昵称
      String nickname = '闲鱼用户';
      try {
        final result = await _controller.runJavaScriptReturningResult('''
          (function() {
            // 多种方式尝试获取用户昵称
            var nick = '';
            // 尝试从 cookie 中提取
            var cookies = document.cookie;
            var nickMatch = cookies.match(/lgc=([^;]+)/);
            if (nickMatch) {
              nick = decodeURIComponent(nickMatch[1]);
            }
            // 尝试从页面中提取
            if (!nick) {
              var el = document.querySelector('.my-nick, .user-nick, [class*="nick"], [class*="username"]');
              if (el) nick = el.innerText.trim();
            }
            return nick || '';
          })()
        ''');
        final parsed = result.toString().replaceAll('"', '').trim();
        if (parsed.isNotEmpty) nickname = parsed;
      } catch (_) {
        // 提取昵称失败不影响登录流程
      }

      // 保存登录状态
      await _accountService.onLoginSuccess(nickname: nickname);

      if (!mounted) return;

      // 显示登录成功弹窗
      Get.defaultDialog(
        title: '闲鱼账号登录成功',
        content: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF10B981), size: 48),
              const SizedBox(height: 12),
              Text(
                '欢迎，$nickname',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                '登录凭证已安全存储，现在可以回到设置页同步订单了。\n\n'
                '🔒 知鱼未保存你的账号密码',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        textConfirm: '返回设置',
        confirmTextColor: Colors.white,
        buttonColor: AppTheme.primary,
        onConfirm: () {
          Get.back(); // 关弹窗
          Get.back(result: true); // 回设置页
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnLogin = _accountService.isOnLoginPage(_currentUrl);

    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: AppBar(
        title: const Text('登录闲鱼账号'),
        actions: [
          IconButton(
            tooltip: '刷新页面',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部安全说明
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF0F172A),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded,
                    color: Color(0xFF34D399), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOnLogin
                        ? '🔒 安全通道：你正在淘宝官方页面登录，知鱼不会获取你的密码'
                        : '✅ 登录成功检测中，请稍候...',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // 加载指示器
          if (_isLoadingPage)
            const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              minHeight: 2,
            ),

          // WebView（淘宝官方登录页）
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
