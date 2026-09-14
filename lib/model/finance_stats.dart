import 'dart:math';
import 'package:fishinsight/model/order_transaction.dart';

/// 每日财务聚合指标
class DailyFinancePoint {
  final DateTime date;
  final double revenue; // 销售总额
  final double profit; // 净利润
  final double cost; // 总成本
  final int orderCount; // 成交单数

  const DailyFinancePoint({
    required this.date,
    required this.revenue,
    required this.profit,
    required this.cost,
    required this.orderCount,
  });
}

/// 品类财务分析摘要
class CategoryFinanceSummary {
  final String category;
  final int orderCount;
  final double totalRevenue;
  final double totalProfit;
  final double totalCost;
  final double profitMargin;
  final double roi;

  const CategoryFinanceSummary({
    required this.category,
    required this.orderCount,
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalCost,
    required this.profitMargin,
    required this.roi,
  });
}

/// 财务统计与商业分析计算中枢
class FinanceStats {
  /// 累计总销售额
  static double totalRevenue(List<OrderTransaction> orders) {
    return orders.fold(0.0, (sum, o) => sum + o.sellingPrice);
  }

  /// 累计总净利润
  static double totalProfit(List<OrderTransaction> orders) {
    return orders.fold(0.0, (sum, o) => sum + o.netProfit);
  }

  /// 累计总成本支出（含进价、运费、包材、平台费）
  static double totalCost(List<OrderTransaction> orders) {
    return orders.fold(0.0, (sum, o) => sum + o.totalCost);
  }

  /// 综合平均毛利率 (%)
  static double averageProfitMargin(List<OrderTransaction> orders) {
    final rev = totalRevenue(orders);
    if (rev <= 0) return 0.0;
    return (totalProfit(orders) / rev) * 100;
  }

  /// 综合投资回报率 ROI (%)
  static double overallRoi(List<OrderTransaction> orders) {
    final cost = totalCost(orders);
    if (cost <= 0) return 0.0;
    return (totalProfit(orders) / cost) * 100;
  }

  /// 筛选指定时间范围内的订单
  static List<OrderTransaction> filterBetween(
    List<OrderTransaction> orders,
    DateTime start,
    DateTime end,
  ) {
    return orders.where((o) {
      return o.createdAt.isAfter(start) && o.createdAt.isBefore(end);
    }).toList();
  }

  /// 近 N 天每日财务走势
  static List<DailyFinancePoint> dailyTrend(
    List<OrderTransaction> orders, {
    int days = 7,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<DailyFinancePoint> points = [];

    for (int i = days - 1; i >= 0; i--) {
      final targetDate = today.subtract(Duration(days: i));
      final nextDay = targetDate.add(const Duration(days: 1));

      final dayOrders = orders.where((o) {
        return o.createdAt.isAfter(targetDate.subtract(const Duration(milliseconds: 1))) &&
            o.createdAt.isBefore(nextDay);
      }).toList();

      final rev = totalRevenue(dayOrders);
      final prof = totalProfit(dayOrders);
      final cst = totalCost(dayOrders);

      points.add(DailyFinancePoint(
        date: targetDate,
        revenue: rev,
        profit: prof,
        cost: cst,
        orderCount: dayOrders.length,
      ));
    }
    return points;
  }

  /// 按品类统计与排行（按净利润贡献从高到低排序）
  static List<CategoryFinanceSummary> categoryRankings(
    List<OrderTransaction> orders,
  ) {
    final Map<String, List<OrderTransaction>> group = {};
    for (final o in orders) {
      final cat = o.category.trim().isEmpty ? '未分类' : o.category.trim();
      group.putIfAbsent(cat, () => []).add(o);
    }

    final List<CategoryFinanceSummary> list = [];
    group.forEach((cat, items) {
      final rev = totalRevenue(items);
      final prof = totalProfit(items);
      final cost = totalCost(items);
      final margin = rev > 0 ? (prof / rev) * 100 : 0.0;
      final roi = cost > 0 ? (prof / cost) * 100 : 0.0;

      list.add(CategoryFinanceSummary(
        category: cat,
        orderCount: items.length,
        totalRevenue: rev,
        totalProfit: prof,
        totalCost: cost,
        profitMargin: margin,
        roi: roi,
      ));
    });

    list.sort((a, b) => b.totalProfit.compareTo(a.totalProfit));
    return list;
  }

  /// 状态分布统计
  static Map<OrderStatus, int> statusCounts(List<OrderTransaction> orders) {
    final Map<OrderStatus, int> map = {
      OrderStatus.pendingDelivery: 0,
      OrderStatus.shipped: 0,
      OrderStatus.completed: 0,
      OrderStatus.afterSale: 0,
    };
    for (final o in orders) {
      map[o.status] = (map[o.status] ?? 0) + 1;
    }
    return map;
  }
}
