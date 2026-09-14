import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fishinsight/database/database_helper.dart';
import 'package:fishinsight/design/app_theme.dart';
import 'package:fishinsight/service/xianyu_account_service.dart';
import 'package:fishinsight/service/xianyu_sync_service.dart';

/// 闲鱼订单同步页
///
/// 登录成功后，利用 WebView 内已持久化的 Cookie 加载闲鱼网页版，
/// 通过 JS 注入从页面中提取已卖出订单数据并导入知鱼财务系统。
class XianyuSyncPage extends StatefulWidget {
  const XianyuSyncPage({super.key});

  @override
  State<XianyuSyncPage> createState() => _XianyuSyncPageState();
}

class _XianyuSyncPageState extends State<XianyuSyncPage> {
  DatabaseHelper get _db => Get.find<DatabaseHelper>();
  late final XianyuAccountService _accountService;
  late final XianyuSyncService _syncService;
  late final WebViewController _controller;

  bool _isLoadingPage = true;
  bool _isExtracting = false;
  bool _needsReLogin = false;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _accountService = XianyuAccountService(_db);
    _syncService = XianyuSyncService(_db);

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
            // 如果被重定向到登录页，说明 Cookie 已过期
            _checkCookieExpiry(url);
          },
          onWebResourceError: (error) {
            debugPrint('Sync WebView error: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'FishInsightBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleExtractedData(message.message);
        },
      )
      // 加载闲鱼网页版（WebView 会自动携带登录时保存的 Cookie）
      ..loadRequest(Uri.parse(XianyuAccountService.goofishHomeUrl));
  }

  /// 检测 Cookie 是否过期（被重定向到登录页）
  void _checkCookieExpiry(String url) {
    if (_accountService.isOnLoginPage(url)) {
      setState(() => _needsReLogin = true);
    }
  }

  /// 执行页面订单提取脚本
  Future<void> _extractOrdersFromPage() async {
    if (_needsReLogin) {
      _showReLoginDialog();
      return;
    }

    setState(() => _isExtracting = true);

    // 注入 JavaScript 脚本：多策略提取闲鱼已售订单
    const jsScript = r'''
      (function() {
        try {
          const results = [];
          
          // 策略一：尝试获取页面全局数据对象
          if (window.__INITIAL_DATA__ && window.__INITIAL_DATA__.soldList) {
            const list = window.__INITIAL_DATA__.soldList;
            list.forEach(item => {
              results.push({
                title: item.title || item.itemTitle || '',
                price: item.price || item.soldPrice || 0,
                status: item.statusText || item.orderStatus || '交易成功',
                orderNumber: item.orderId || item.bizOrderId || '',
                buyer: item.buyerNick || ''
              });
            });
          }

          // 策略二：尝试 __NEXT_DATA__ 或 __NUXT_DATA__（SSR 框架常见数据注入）
          var globalData = window.__NEXT_DATA__ || window.__NUXT_DATA__ || window.__APP_DATA__;
          if (globalData) {
            try {
              var dataStr = typeof globalData === 'string' ? globalData : JSON.stringify(globalData);
              // 搜索包含订单相关字段的对象
              var orderPattern = /"(?:orderId|bizOrderId)":\s*"(\d+)"/g;
              var match;
              while ((match = orderPattern.exec(dataStr)) !== null) {
                // 找到了订单 ID，尝试提取整个订单对象
              }
            } catch(e) {}
          }

          // 策略三：DOM 智能启发式检索
          const priceEls = Array.from(document.querySelectorAll('*')).filter(el => {
            return el.children.length === 0 && /^¥?\s*\d+(\.\d{1,2})?$/.test(el.innerText.trim());
          });

          priceEls.forEach((pEl, idx) => {
            let card = pEl.parentElement;
            for (let i = 0; i < 5 && card && card !== document.body; i++) {
              const text = card.innerText;
              if (text.length > 10 && text.length < 300) {
                break;
              }
              card = card.parentElement;
            }

            if (card) {
              const fullText = card.innerText;
              const lines = fullText.split(/\r?\n/).map(s => s.trim()).filter(Boolean);
              
              let title = '';
              let status = '交易成功';
              let price = pEl.innerText.replace(/[^0-9.]/g, '');

              for (const line of lines) {
                if (line.includes('交易成功') || line.includes('待发货') || line.includes('已发货') || line.includes('退款')) {
                  status = line;
                } else if (line.length > title.length && !line.includes('¥') && isNaN(Number(line))) {
                  title = line;
                }
              }

              if (title && price) {
                results.push({
                  title: title,
                  price: parseFloat(price) || 0,
                  status: status,
                  orderNumber: 'XY' + Date.now().toString().slice(-6) + idx,
                  buyer: '闲鱼买家'
                });
              }
            }
          });

          // 去重
          const uniqueResults = [];
          const seen = new Set();
          for (const r of results) {
            const key = r.orderNumber || r.title;
            if (!seen.has(key)) {
              seen.add(key);
              uniqueResults.push(r);
            }
          }

          FishInsightBridge.postMessage(JSON.stringify(uniqueResults));
        } catch (err) {
          FishInsightBridge.postMessage(JSON.stringify({ error: err.toString() }));
        }
      })();
    ''';

    await _controller.runJavaScript(jsScript);
  }

  /// 处理 JS 提取到的订单数据
  void _handleExtractedData(String rawJson) async {
    setState(() => _isExtracting = false);

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map && decoded.containsKey('error')) {
        _showNoDataDialog(hint: '提取脚本出错：${decoded['error']}');
        return;
      }
      if (decoded is List) {
        final list = decoded.cast<Map<String, dynamic>>();
        if (list.isEmpty) {
          _showNoDataDialog();
          return;
        }

        final count = await _syncService.importRawOrders(list);
        Get.defaultDialog(
          title: '闲鱼订单同步成功',
          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF10B981), size: 48),
                const SizedBox(height: 12),
                Text(
                  '已成功提取并导入 $count 笔闲鱼订单！',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  '财务大盘已同步更新流水、成本与利润。',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          textConfirm: '查看财务大盘',
          confirmTextColor: Colors.white,
          buttonColor: AppTheme.primary,
          onConfirm: () {
            Get.back(); // 关弹窗
            Get.back(result: true); // 回主页
          },
        );
      } else {
        _showNoDataDialog();
      }
    } catch (e) {
      _showNoDataDialog(hint: '数据解析失败：$e');
    }
  }

  void _showNoDataDialog({String? hint}) {
    Get.defaultDialog(
      title: '未检测到订单数据',
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          hint ??
              '请先在下方页面中找到「我卖出的」列表，确保页面上显示了订单信息后，'
                  '再点击顶部的【提取订单】按钮。\n\n'
                  '💡 提示：部分页面可能需要点击进入个人主页或订单页面才能看到已卖出的商品。',
          style:
              const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
      ),
      textConfirm: '知道了',
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.primary,
      onConfirm: () => Get.back(),
    );
  }

  void _showReLoginDialog() {
    Get.defaultDialog(
      title: '登录已过期',
      content: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          '你的闲鱼登录凭证已过期，请返回设置页重新登录后再同步。\n\n'
          '这是淘宝的安全策略，登录凭证通常 7 天后自动失效。',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
      ),
      textConfirm: '返回重新登录',
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.primary,
      onConfirm: () {
        Get.back(); // 关弹窗
        Get.back(); // 回设置页
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: AppBar(
        title: const Text('同步闲鱼订单'),
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
          // 操作栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF0F172A),
            child: Row(
              children: [
                Icon(
                  _needsReLogin
                      ? Icons.warning_amber_rounded
                      : Icons.cloud_sync_rounded,
                  color: _needsReLogin
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF34D399),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _needsReLogin
                        ? '⚠️ 登录已过期，请返回设置页重新登录'
                        : '请导航到「我卖出的」页面，再点击右侧按钮提取订单',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed:
                      (_isExtracting || _needsReLogin) ? null : _extractOrdersFromPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF475569),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isExtracting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download_rounded, size: 16),
                  label: Text(
                    _isExtracting ? '提取中...' : '提取订单',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
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

          // 闲鱼网页版 WebView
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
