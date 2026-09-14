import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fishinsight/database/database_helper.dart';
import 'package:fishinsight/design/app_theme.dart';
import 'package:fishinsight/service/xianyu_sync_service.dart';

class XianyuLoginPage extends StatefulWidget {
  const XianyuLoginPage({super.key});

  @override
  State<XianyuLoginPage> createState() => _XianyuLoginPageState();
}

class _XianyuLoginPageState extends State<XianyuLoginPage> {
  DatabaseHelper get _db => Get.find<DatabaseHelper>();
  late final XianyuSyncService _syncService;

  late final WebViewController _controller;
  bool _isLoadingPage = true;
  bool _isExtracting = false;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _syncService = XianyuSyncService(_db);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoadingPage = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoadingPage = false;
              _currentUrl = url;
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'FishInsightBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleExtractedData(message.message);
        },
      )
      ..loadRequest(Uri.parse('https://m.goofish.com/my/sold'));
  }

  /// 执行页面提取脚本
  Future<void> _extractOrdersFromPage() async {
    setState(() => _isExtracting = true);

    // 注入 JavaScript 脚本：深度提取闲鱼已售列表页的所有订单与金额信息
    const jsScript = r'''
      (function() {
        try {
          const results = [];
          
          // 方式一：尝试获取页面全局数据对象
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

          // 方式二：DOM 智能启发式检索
          // 查找包含价格符号 ¥ 的区块及其父级卡片
          const priceEls = Array.from(document.querySelectorAll('*')).filter(el => {
            return el.children.length === 0 && /^¥?\\s*\\d+(\\.\\d{1,2})?$/.test(el.innerText.trim());
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
              
              // 寻找标题：通常是卡片中除状态和价格外最长的一行
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
            if (!seen.has(r.title)) {
              seen.add(r.title);
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

  void _handleExtractedData(String rawJson) async {
    setState(() => _isExtracting = false);

    try {
      final decoded = jsonDecode(rawJson);
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
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
                const SizedBox(height: 12),
                Text(
                  '已成功提取并导入 $count 笔真实闲鱼订单！',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
            Get.back(result: true); // 回到主页
          },
        );
      } else {
        _showNoDataDialog();
      }
    } catch (e) {
      _showNoDataDialog();
    }
  }

  void _showNoDataDialog() {
    Get.defaultDialog(
      title: '未检测到已卖出商品列表',
      content: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          '请先在下方页面中完成官方登录，并切换到「我卖出的」页面后，再次点击顶部的【一键同步订单】按钮！',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
      ),
      textConfirm: '知道了',
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.primary,
      onConfirm: () => Get.back(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: AppBar(
        title: const Text('官方登录与一键同步'),
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
          // 顶部安全说明与同步操作条
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF0F172A),
            child: Row(
              children: [
                const Icon(Icons.security_rounded, color: Color(0xFF34D399), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '官方安全通道：登录全程由阿里巴巴提供，知鱼仅在您授权后提取已售订单',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isExtracting ? null : _extractOrdersFromPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isExtracting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_download_rounded, size: 16),
                  label: Text(_isExtracting ? '正在抓取...' : '一键同步订单',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          if (_isLoadingPage)
            const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              minHeight: 2,
            ),

          // 核心官方 WebView
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
