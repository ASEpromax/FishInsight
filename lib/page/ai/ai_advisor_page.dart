import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:fishinsight/database/database_helper.dart';
import 'package:fishinsight/design/app_theme.dart';
import 'package:fishinsight/model/finance_stats.dart';
import 'package:fishinsight/model/order_transaction.dart';

class AiAdvisorPage extends StatefulWidget {
  const AiAdvisorPage({super.key});

  @override
  State<AiAdvisorPage> createState() => _AiAdvisorPageState();
}

class _AiAdvisorPageState extends State<AiAdvisorPage> {
  DatabaseHelper get _db => Get.find<DatabaseHelper>();

  bool _loading = false;
  String _diagnosisReport = '';
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _apiKey = _db.getSetting('deepseek_api_key', defaultValue: '');
  }

  void _configureApiKey() {
    final controller = TextEditingController(text: _apiKey);
    Get.defaultDialog(
      title: '配置 DeepSeek API Key',
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            const Text(
              '输入您的 DeepSeek 或兼容 OpenAI 格式的 API 密钥，即可开启实时大模型商业诊断：',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'sk-...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
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

  Future<void> _generateDiagnosis() async {
    setState(() {
      _loading = true;
      _diagnosisReport = '';
    });

    final orders = _db.getOrders();
    final totalRev = FinanceStats.totalRevenue(orders);
    final totalProf = FinanceStats.totalProfit(orders);
    final avgMargin = FinanceStats.averageProfitMargin(orders);
    final categoryRankings = FinanceStats.categoryRankings(orders);

    final catSummary = categoryRankings
        .map((c) =>
            '【${c.category}】单数:${c.orderCount} 销售:¥${c.totalRevenue.toStringAsFixed(0)} 净利:¥${c.totalProfit.toStringAsFixed(0)} ROI:${c.roi.toStringAsFixed(1)}%')
        .join('\n');

    final prompt = '''
你是一位拥有10年电商与二手闲鱼市场交易经验的资深商业财务与选品诊断专家。请根据以下真实卖家的闲鱼交易与财务数据，为该卖家出具一份深度《闲鱼商业与财务诊断报告》：

【卖家核心财务大盘】
- 累计总订单数：${orders.length} 单
- 累计销售额流水：¥${totalRev.toStringAsFixed(2)}
- 累计实赚净毛利：¥${totalProf.toStringAsFixed(2)}
- 整体平均毛利率：${avgMargin.toStringAsFixed(1)}%

【各品类表现排行】
$catSummary

请按以下结构输出条理清晰、言简意赅的专业诊断分析：
1. 🏆 经营健康度综合评定（星级与总体评价）
2. 💡 黄金盈利品类深度复盘（哪些品类是利润主力，为什么能赚）
3. ⚠️ 潜在经营短板与成本漏损警示（关注运费、闲鱼扣点、低周转风险）
4. 🚀 闲鱼下一步选品与定价操作建议（具体到下周的行动清单）
''';

    if (_apiKey.isEmpty) {
      // 演示模拟诊断
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _loading = false;
        _diagnosisReport = _buildLocalDemoDiagnosis(orders, totalRev, totalProf, avgMargin, categoryRankings);
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.deepseek.com/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'deepseek-chat',
          'messages': [
            {'role': 'system', 'content': '你是一位严谨幽默、极其擅长二手电商与财务分析的商业顾问。'},
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;
        setState(() {
          _diagnosisReport = content;
          _loading = false;
        });
      } else {
        setState(() {
          _diagnosisReport = '调用 DeepSeek API 失败 (HTTP ${response.statusCode})，请检查 API Key 是否有效。已自动切换为本地专家诊断模型。\n\n' +
              _buildLocalDemoDiagnosis(orders, totalRev, totalProf, avgMargin, categoryRankings);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _diagnosisReport = '网络请求异常，已切换为本地专家规则诊断：\n\n' +
            _buildLocalDemoDiagnosis(orders, totalRev, totalProf, avgMargin, categoryRankings);
        _loading = false;
      });
    }
  }

  String _buildLocalDemoDiagnosis(
    List<OrderTransaction> orders,
    double totalRev,
    double totalProf,
    double avgMargin,
    List<CategoryFinanceSummary> rankings,
  ) {
    final bestCat = rankings.isNotEmpty ? rankings.first.category : '暂无';
    return '''
### 🏆 经营健康度综合评定：★★★★☆ (优良)
- **总体评价**：整体毛利率达到 **${avgMargin.toStringAsFixed(1)}%**，在二手电商领域表现相当亮眼，具备非常清晰的高毛利产品结构。

### 💡 黄金盈利品类深度复盘
- **第一功臣【$bestCat】**：净利润与回报率双高，是您当前资金滚雪球的核心驱动力。
- **差异化优势**：二手书籍与潮玩类目客单价虽小，但进货成本极低，ROI 甚至可达 100%~200% 以上，是极佳的流量与现金流补充款。

### ⚠️ 潜在经营短板与成本漏损警示
1. **小件商品运费侵蚀**：对低单价（如50元以下）商品，首重8~10元的快递费会瞬间吃掉 20% 以上的利润，建议优先让买家凑单或设置自提/顺丰到付。
2. **闲鱼服务费与沉淀资金**：当前已发货订单存在资金在途期，需密切关注买家签收后是否主动确认收货，降低资金占用天数。

### 🚀 闲鱼下一步选品与定价操作建议
1. **扩充 $bestCat 货源储备**：加大该品类的捡漏巡检频次，制定标准化收货质检与上架模版。
2. **定价锚点战术**：闲鱼买家普遍喜欢小刀，建议挂牌价在目标成交价基础上上浮 10%~15%，预留砍价空间促成极速成交。
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: AppBar(
        title: const Text('知鱼 AI · 商业参谋'),
        actions: [
          IconButton(
            tooltip: '配置 API 密钥',
            icon: const Icon(Icons.key_rounded),
            onPressed: _configureApiKey,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 顶部介绍卡片
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFDE047), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DeepSeek 驱动的闲鱼数据脑',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _apiKey.isNotEmpty ? '已接入 DeepSeek API · 商业模型已就绪' : '当前使用本地规则诊断 · 点击右上角可填 API Key',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _loading ? null : _generateDiagnosis,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.analytics_rounded),
            label: Text(_loading ? 'AI 商业大脑正在深度透视账本...' : '一键生成闲鱼商业与财务诊断报告',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),

          if (_diagnosisReport.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.insights_rounded, size: 20, color: Color(0xFF4338CA)),
                        const SizedBox(width: 8),
                        const Text(
                          '诊断与策略结论',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const Spacer(),
                        Text(
                          DateTime.now().toString().substring(0, 16),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 14),
                    SelectableText(
                      _diagnosisReport,
                      style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
