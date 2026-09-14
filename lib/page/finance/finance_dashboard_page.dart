import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fishinsight/database/database_helper.dart';
import 'package:fishinsight/design/app_theme.dart';
import 'package:fishinsight/model/finance_stats.dart';
import 'package:fishinsight/model/order_transaction.dart';
import 'package:fishinsight/page/order/order_edit_page.dart';

class FinanceDashboardPage extends StatefulWidget {
  const FinanceDashboardPage({super.key});

  @override
  State<FinanceDashboardPage> createState() => _FinanceDashboardPageState();
}

class _FinanceDashboardPageState extends State<FinanceDashboardPage> {
  DatabaseHelper get _db => Get.find<DatabaseHelper>();
  List<OrderTransaction> _orders = [];
  int _trendDays = 7; // 7 或 30 天

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _orders = _db.getOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalRev = FinanceStats.totalRevenue(_orders);
    final totalProf = FinanceStats.totalProfit(_orders);
    final totalCost = FinanceStats.totalCost(_orders);
    final avgMargin = FinanceStats.averageProfitMargin(_orders);
    final overallRoi = FinanceStats.overallRoi(_orders);

    final trends = FinanceStats.dailyTrend(_orders, days: _trendDays);
    final categoryRankings = FinanceStats.categoryRankings(_orders);
    final statusMap = FinanceStats.statusCounts(_orders);

    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: AppBar(
        title: const Text('知鱼 · 商业财务透视'),
        actions: [
          IconButton(
            tooltip: '刷新数据',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Get.to(() => const OrderEditPage());
          if (res == true) _loadData();
        },
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_chart_rounded, color: Colors.white),
        label: const Text('记账 / 录单', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadData(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. 核心资产与利润总览卡片 (Hero Profit Card)
            _buildHeroProfitCard(totalRev, totalProf, totalCost, avgMargin, overallRoi),
            const SizedBox(height: 16),

            // 2. 闲鱼履约流转与待结算资金
            _buildPipelineSummaryCard(statusMap),
            const SizedBox(height: 16),

            // 3. 趋势图表区 (近7天/近30天走势)
            _buildTrendSection(trends),
            const SizedBox(height: 16),

            // 4. 成本结构透视 (进价 / 运费 / 扣点 / 耗材)
            _buildCostBreakdownCard(),
            const SizedBox(height: 16),

            // 5. 品类收益力与 ROI 排行榜
            _buildCategoryRankingsCard(categoryRankings),
            const SizedBox(height: 80), // 底部留白给 FAB
          ],
        ),
      ),
    );
  }

  /// 顶部收益大牌 (Hero Card)
  Widget _buildHeroProfitCard(
    double rev,
    double prof,
    double cost,
    double margin,
    double roi,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '累计净毛利 (实赚盈余)',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '毛利率 ${AppTheme.formatPercent(margin)}',
                  style: const TextStyle(color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppTheme.formatMoney(prof),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildHeroStatItem('销售总流水', AppTheme.formatMoney(rev), Colors.white),
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                Expanded(
                  child: _buildHeroStatItem('全要素总成本', AppTheme.formatMoney(cost), const Color(0xFFF87171)),
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                Expanded(
                  child: _buildHeroStatItem('投资回报率 ROI', AppTheme.formatPercent(roi), const Color(0xFFFBBF24)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 履约流转与状态看板
  Widget _buildPipelineSummaryCard(Map<OrderStatus, int> statusMap) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '交易履约管线',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatusChip('待发货', statusMap[OrderStatus.pendingDelivery] ?? 0, const Color(0xFFF59E0B)),
                _buildStatusChip('已发货', statusMap[OrderStatus.shipped] ?? 0, const Color(0xFF3B82F6)),
                _buildStatusChip('已完成', statusMap[OrderStatus.completed] ?? 0, const Color(0xFF10B981)),
                _buildStatusChip('售后纠纷', statusMap[OrderStatus.afterSale] ?? 0, const Color(0xFFEF4444)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.9))),
          ],
        ),
      ),
    );
  }

  /// 趋势走势图卡片
  Widget _buildTrendSection(List<DailyFinancePoint> trends) {
    final maxProfit = trends.fold(0.0, (prev, p) => max(prev, max(p.profit, p.revenue)));
    final chartCeiling = maxProfit > 0 ? maxProfit * 1.15 : 100.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '收支走势分析',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildDaysToggle(7, '近7天'),
                      _buildDaysToggle(30, '近30天'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildLegendItem('销售额', const Color(0xFF94A3B8)),
                const SizedBox(width: 12),
                _buildLegendItem('纯利润', const Color(0xFF10B981)),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: trends.map((point) {
                  final revH = (point.revenue / chartCeiling) * 120;
                  final profH = (max(0.0, point.profit) / chartCeiling) * 120;

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 6,
                              height: max(3.0, revH),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Container(
                              width: 6,
                              height: max(3.0, profH),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${point.date.month}.${point.date.day}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysToggle(int days, String label) {
    final active = _trendDays == days;
    return GestureDetector(
      onTap: () => setState(() => _trendDays = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }

  /// 成本结构分解卡片
  Widget _buildCostBreakdownCard() {
    double costGoods = 0;
    double costShipping = 0;
    double costPlatform = 0;
    double costPackage = 0;

    for (final o in _orders) {
      costGoods += o.costPrice;
      costShipping += o.shippingFee;
      costPlatform += o.platformFee;
      costPackage += o.packagingFee;
    }

    final total = costGoods + costShipping + costPlatform + costPackage;
    if (total <= 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '全要素成本构成透视',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    _buildCostBarSegment(costGoods / total, const Color(0xFF3B82F6)),
                    _buildCostBarSegment(costShipping / total, const Color(0xFFF59E0B)),
                    _buildCostBarSegment(costPlatform / total, const Color(0xFF10B981)),
                    _buildCostBarSegment(costPackage / total, const Color(0xFF8B5CF6)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCostItem('进货成本', costGoods, costGoods / total, const Color(0xFF3B82F6)),
                _buildCostItem('快递运费', costShipping, costShipping / total, const Color(0xFFF59E0B)),
                _buildCostItem('闲鱼扣点', costPlatform, costPlatform / total, const Color(0xFF10B981)),
                _buildCostItem('包材耗材', costPackage, costPackage / total, const Color(0xFF8B5CF6)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostBarSegment(double flex, Color color) {
    if (flex <= 0) return const SizedBox.shrink();
    return Expanded(
      flex: (flex * 1000).toInt().clamp(1, 1000),
      child: Container(color: color),
    );
  }

  Widget _buildCostItem(String label, double amount, double ratio, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 2),
        Text(AppTheme.compactCurrencyFormat.format(amount),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        Text('${(ratio * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
      ],
    );
  }

  /// 品类利润贡献与 ROI 排行
  Widget _buildCategoryRankingsCard(List<CategoryFinanceSummary> rankings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '品类吸金力与 ROI 排行',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text('${rankings.length} 个品类', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
            const SizedBox(height: 12),
            if (rankings.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('暂无品类数据', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
              )
            else
              ...rankings.map((cat) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.category_outlined, size: 16, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.category,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '共 ${cat.orderCount} 单 · 销售 ${AppTheme.formatMoney(cat.totalRevenue)}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '+${AppTheme.formatMoney(cat.totalProfit)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ROI ${cat.roi.toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}
