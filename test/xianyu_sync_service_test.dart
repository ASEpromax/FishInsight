import 'package:flutter_test/flutter_test.dart';
import 'package:fishinsight/model/order_transaction.dart';
import 'package:fishinsight/service/xianyu_sync_service.dart';

void main() {
  group('XianyuSyncService 智能解析测试', () {
    test('品类智能分类识别应准确', () {
      expect(XianyuSyncService.classifyCategory('Sony A7M4 微单全画幅机身'), '数码3C');
      expect(XianyuSyncService.classifyCategory('2026肖秀荣考研政治全套教材资料'), '二手书籍');
      expect(XianyuSyncService.classifyCategory('泡泡玛特 DIMOO 隐藏款手办盲盒'), '潮玩模玩');
      expect(XianyuSyncService.classifyCategory('Nike Air Force 1 经典空军一号板鞋'), '服饰鞋包');
      expect(XianyuSyncService.classifyCategory('雅诗兰黛小棕瓶精华 50ml'), '美妆个护');
      expect(XianyuSyncService.classifyCategory('好孩子婴儿推车 便携折叠童车'), '母婴闲置');
      expect(XianyuSyncService.classifyCategory('宜家折叠书桌 学习电脑桌'), '家居日用');
      expect(XianyuSyncService.classifyCategory('未知闲置物品一件'), '综合闲置');
    });

    test('订单状态转换应准确', () {
      expect(XianyuSyncService.parseOrderStatus('交易成功'), OrderStatus.completed);
      expect(XianyuSyncService.parseOrderStatus('买家已付款，请尽快发货'), OrderStatus.pendingDelivery);
      expect(XianyuSyncService.parseOrderStatus('已发货，等待买家确认收货'), OrderStatus.shipped);
      expect(XianyuSyncService.parseOrderStatus('退款中，等待商家处理'), OrderStatus.afterSale);
    });

    test('价格清洗与提取应准确', () {
      expect(XianyuSyncService.parsePrice('¥4,850.00'), 4850.0);
      expect(XianyuSyncService.parsePrice('¥ 299'), 299.0);
      expect(XianyuSyncService.parsePrice(188.5), 188.5);
      expect(XianyuSyncService.parsePrice(null), 0.0);
    });
  });
}
