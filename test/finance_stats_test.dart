import 'package:flutter_test/flutter_test.dart';
import 'package:fishinsight/model/order_transaction.dart';
import 'package:fishinsight/model/finance_stats.dart';

void main() {
  group('OrderTransaction 财务精算测试', () {
    test('单笔利润与扣点计算应准确无误', () {
      final order = OrderTransaction(
        title: '测试微单相机',
        costPrice: 4000.0,
        sellingPrice: 5000.0,
        shippingFee: 30.0,
        packagingFee: 10.0,
        platformFeeRate: 0.006, // 0.6% -> 30元
        otherExpense: 0.0,
      );

      // 平台服务费 = 5000 * 0.006 = 30.0
      expect(order.platformFee, closeTo(30.0, 0.01));

      // 全要素成本 = 4000 + 30 + 10 + 30 = 4070.0
      expect(order.totalCost, closeTo(4070.0, 0.01));

      // 单笔净毛利 = 5000 - 4070 = 930.0
      expect(order.netProfit, closeTo(930.0, 0.01));

      // 毛利率 = (930 / 5000) * 100 = 18.6%
      expect(order.profitMargin, closeTo(18.6, 0.01));

      // 投资回报率 ROI = (930 / 4000) * 100 = 23.25%
      expect(order.roi, closeTo(23.25, 0.01));
    });

    test('序列化与反序列化应完整保真', () {
      final order = OrderTransaction(
        title: '测试手办',
        category: '潮玩模玩',
        buyerNickname: '测试买家',
        costPrice: 100.0,
        sellingPrice: 250.0,
        status: OrderStatus.completed,
      );

      final str = order.serialize();
      final restored = OrderTransaction.deserialize(str);

      expect(restored.title, '测试手办');
      expect(restored.category, '潮玩模玩');
      expect(restored.status, OrderStatus.completed);
      expect(restored.costPrice, 100.0);
      expect(restored.sellingPrice, 250.0);
    });
  });

  group('FinanceStats 商业大盘聚合分析测试', () {
    final now = DateTime.now();
    final orders = [
      OrderTransaction(
        title: '数码产品A',
        category: '数码3C',
        createdAt: now,
        costPrice: 1000.0,
        sellingPrice: 1500.0,
        shippingFee: 20.0,
        packagingFee: 5.0,
        platformFeeRate: 0.006, // 9.0
      ), // netProfit = 1500 - (1000+20+5+9) = 466.0
      OrderTransaction(
        title: '潮玩B',
        category: '潮玩模玩',
        createdAt: now,
        costPrice: 100.0,
        sellingPrice: 300.0,
        shippingFee: 10.0,
        packagingFee: 2.0,
        platformFeeRate: 0.006, // 1.8
      ), // netProfit = 300 - (100+10+2+1.8) = 186.2
    ];

    test('总流水与总毛利聚合计算', () {
      expect(FinanceStats.totalRevenue(orders), closeTo(1800.0, 0.01));
      expect(FinanceStats.totalProfit(orders), closeTo(652.2, 0.01));
    });

    test('品类排行榜应按净利润从高到低排序', () {
      final rankings = FinanceStats.categoryRankings(orders);
      expect(rankings.length, 2);
      expect(rankings.first.category, '数码3C');
      expect(rankings.first.totalProfit, closeTo(466.0, 0.01));
      expect(rankings[1].category, '潮玩模玩');
      expect(rankings[1].totalProfit, closeTo(186.2, 0.01));
    });
  });
}
