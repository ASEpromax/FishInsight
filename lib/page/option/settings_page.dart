import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fishinsight/database/database_helper.dart';
import 'package:fishinsight/design/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  DatabaseHelper get _db => Get.find<DatabaseHelper>();

  double _platformFeeRate = 0.006;
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    final rateStr = _db.getSetting('platform_fee_rate', defaultValue: '0.006');
    _platformFeeRate = double.tryParse(rateStr) ?? 0.006;
    _apiKey = _db.getSetting('deepseek_api_key', defaultValue: '');
  }

  void _editPlatformFee() {
    final controller = TextEditingController(text: (_platformFeeRate * 100).toStringAsFixed(2));
    Get.defaultDialog(
      title: '设置闲鱼平台默认扣点率',
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          // 业务规则卡片
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('闲鱼业务与核算规则', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                ListTile(
                  leading: const Icon(Icons.percent_rounded, color: Color(0xFFF59E0B)),
                  title: const Text('默认平台服务费率'),
                  subtitle: Text('${(_platformFeeRate * 100).toStringAsFixed(2)}% (录单时自动带入)'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _editPlatformFee,
                ),
                ListTile(
                  leading: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1)),
                  title: const Text('AI 商业参谋密钥 (DeepSeek)'),
                  subtitle: Text(_apiKey.isNotEmpty ? '已配置密钥 (sk-***)' : '未配置 (使用本地专家模型)'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _editApiKey,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 数据资产卡片
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('数据安全与隐私', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined, color: Color(0xFF3B82F6)),
                  title: const Text('导出本地账本与订单 (JSON)'),
                  subtitle: const Text('数据全部存放于手机本地 Hive 数据库'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _exportJson,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 关于知鱼
          const Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('关于知鱼', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                ListTile(
                  leading: Icon(Icons.info_outline_rounded, color: Color(0xFF10B981)),
                  title: Text('知鱼 (FishInsight)'),
                  subtitle: Text('版本 1.0.0 · 闲鱼商业智能与财务分析系统'),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    '“子非鱼，安知鱼之乐？子非我，安知我不知鱼之乐？”\n为闲鱼个人卖家、二手电商创作者打造的极简商业决策与财务中枢。',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.5),
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
