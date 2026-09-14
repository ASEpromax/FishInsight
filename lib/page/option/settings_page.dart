import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fishinsight/database/database_helper.dart';
import 'package:fishinsight/design/app_theme.dart';
import 'package:fishinsight/service/xianyu_account_service.dart';
import 'package:fishinsight/page/sync/xianyu_login_page.dart';
import 'package:fishinsight/page/sync/xianyu_sync_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  DatabaseHelper get _db => Get.find<DatabaseHelper>();
  late final XianyuAccountService _accountService;

  double _platformFeeRate = 0.006;
  String _apiKey = '';

  // 账号状态（异步加载）
  bool _isLoggedIn = false;
  String _nickname = '';
  String _loginTime = '';
  String _lastSyncTime = '';

  @override
  void initState() {
    super.initState();
    _accountService = XianyuAccountService(_db);
    final rateStr = _db.getSetting('platform_fee_rate', defaultValue: '0.006');
    _platformFeeRate = double.tryParse(rateStr) ?? 0.006;
    _apiKey = _db.getSetting('deepseek_api_key', defaultValue: '');
    _loadAccountStatus();
  }

  Future<void> _loadAccountStatus() async {
    final loggedIn = await _accountService.isLoggedIn();
    final nick = await _accountService.getNickname();
    final loginT = await _accountService.getLoginTimeFormatted();
    final syncT = _accountService.getLastSyncTime();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _nickname = nick;
      _loginTime = loginT;
      _lastSyncTime = syncT;
    });
  }

  // —————— 登录 ——————
  void _goLogin() async {
    final result = await Get.to(() => const XianyuLoginPage());
    if (result == true) {
      await _loadAccountStatus();
    }
  }

  // —————— 同步 ——————
  void _goSync() async {
    final result = await Get.to(() => const XianyuSyncPage());
    if (result == true) {
      await _loadAccountStatus();
    }
  }

  // —————— 退出登录 ——————
  void _confirmLogout() {
    Get.defaultDialog(
      title: '确认退出闲鱼账号？',
      content: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          '退出后将清除本地登录凭证（Cookie），已导入的订单数据不会被删除。\n\n'
          '下次同步需要重新登录。',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
      ),
      textConfirm: '退出登录',
      textCancel: '取消',
      confirmTextColor: Colors.white,
      buttonColor: const Color(0xFFEF4444),
      onConfirm: () async {
        await _accountService.logout();
        Get.back();
        await _loadAccountStatus();
        Get.snackbar('已退出', '闲鱼账号已安全退出，本地登录凭证已清除',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF1E293B),
            colorText: Colors.white,
            duration: const Duration(seconds: 2));
      },
    );
  }

  // —————— 编辑平台扣点 ——————
  void _editPlatformFee() {
    final controller = TextEditingController(
        text: (_platformFeeRate * 100).toStringAsFixed(2));
    Get.defaultDialog(
      title: '设置闲鱼平台默认扣点率',
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '扣点比例 (%)',
            suffixText: '%',
            helperText: '闲鱼目前基础软件服务费一般为 0.6%',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      textConfirm: '保存',
      textCancel: '取消',
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.primary,
      onConfirm: () async {
        final val = double.tryParse(controller.text.trim()) ?? 0.6;
        final rate = val / 100;
        await _db.setSetting('platform_fee_rate', rate.toString());
        setState(() => _platformFeeRate = rate);
        Get.back();
      },
    );
  }

  // —————— 编辑 API Key ——————
  void _editApiKey() {
    final controller = TextEditingController(text: _apiKey);
    Get.defaultDialog(
      title: '配置 DeepSeek API Key',
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'sk-...',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ),
      textConfirm: '保存',
      textCancel: '取消',
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.primary,
      onConfirm: () async {
        final val = controller.text.trim();
        await _db.setSetting('deepseek_api_key', val);
        setState(() => _apiKey = val);
        Get.back();
      },
    );
  }

  // —————— 导出 JSON ——————
  void _exportJson() {
    final orders = _db.getOrders();
    final jsonStr = jsonEncode(orders.map((o) => o.toJson()).toList());
    Get.dialog(
      AlertDialog(
        title: const Text('数据备份 (JSON)'),
        content: SizedBox(
          width: double.maxFinite,
          child: SelectableText(
            jsonStr,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: AppBar(
        title: const Text('设置与系统'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ====== 闲鱼账号卡片 ======
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('闲鱼账号',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),

                if (_isLoggedIn) ...[
                  // —— 已登录状态 ——
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF10B981),
                      child: Icon(Icons.person_rounded,
                          color: Colors.white, size: 22),
                    ),
                    title: Text(
                      _nickname.isNotEmpty ? _nickname : '闲鱼用户',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '登录于 $_loginTime',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),

                  // 一键同步入口
                  ListTile(
                    leading: const Icon(Icons.cloud_sync_rounded,
                        color: Color(0xFFF59E0B)),
                    title: const Text('一键同步订单'),
                    subtitle: Text(
                      _lastSyncTime.isNotEmpty
                          ? '上次同步：$_lastSyncTime'
                          : '尚未同步过',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _goSync,
                  ),

                  // 退出登录
                  ListTile(
                    leading: const Icon(Icons.logout_rounded,
                        color: Color(0xFFEF4444)),
                    title: const Text('退出闲鱼账号',
                        style: TextStyle(color: Color(0xFFEF4444))),
                    subtitle: const Text('已导入的订单不会被删除',
                        style: TextStyle(fontSize: 12)),
                    onTap: _confirmLogout,
                  ),
                ] else ...[
                  // —— 未登录状态 ——
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE2E8F0),
                      child: Icon(Icons.person_outline_rounded,
                          color: Color(0xFF94A3B8), size: 22),
                    ),
                    title: const Text('登录闲鱼账号'),
                    subtitle: const Text(
                      '通过淘宝官方页面安全登录，一键导入已卖出订单',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _goLogin,
                  ),

                  // 安全说明
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 14, color: Color(0xFF10B981)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '知鱼不会保存你的账号密码，登录全程由淘宝官方完成',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ====== 业务规则卡片 ======
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('核算规则',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                ListTile(
                  leading: const Icon(Icons.percent_rounded,
                      color: Color(0xFFF59E0B)),
                  title: const Text('默认平台服务费率'),
                  subtitle: Text(
                      '${(_platformFeeRate * 100).toStringAsFixed(2)}% (录单时自动带入)'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _editPlatformFee,
                ),
                ListTile(
                  leading: const Icon(Icons.auto_awesome_rounded,
                      color: Color(0xFF6366F1)),
                  title: const Text('AI 商业参谋密钥 (DeepSeek)'),
                  subtitle: Text(_apiKey.isNotEmpty
                      ? '已配置密钥 (sk-***)'
                      : '未配置 (使用本地专家模型)'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _editApiKey,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ====== 数据安全卡片 ======
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('数据安全与隐私',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined,
                      color: Color(0xFF3B82F6)),
                  title: const Text('导出本地账本与订单 (JSON)'),
                  subtitle:
                      const Text('数据全部存放于手机本地 Hive 数据库'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _exportJson,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ====== 关于 ======
          const Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('关于知鱼',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                ListTile(
                  leading: Icon(Icons.info_outline_rounded,
                      color: Color(0xFF10B981)),
                  title: Text('知鱼 (FishInsight)'),
                  subtitle: Text('版本 1.1.0 · 闲鱼商业智能与财务分析系统'),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    '"子非鱼，安知鱼之乐？子非我，安知我不知鱼之乐？"\n为闲鱼个人卖家、二手电商创作者打造的极简商业决策与财务中枢。',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF64748B), height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
