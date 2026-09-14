import 'package:fishinsight/database/database_helper.dart';
import 'package:fishinsight/model/order_transaction.dart';

class XianyuSyncService {
  final DatabaseHelper db;

  XianyuSyncService(this.db);

  /// 根据商品标题智能识别品类标签
  static String classifyCategory(String title) {
    final t = title.toLowerCase();

    if (t.contains('iphone') ||
        t.contains('ipad') ||
        t.contains('macbook') ||
        t.contains('苹果') ||
        t.contains('手机') ||
        t.contains('电脑') ||
        t.contains('相机') ||
        t.contains('微单') ||
        t.contains('镜头') ||
        t.contains('耳机') ||
        t.contains('显卡') ||
        t.contains('键盘') ||
        t.contains('数码') ||
        t.contains('索尼') ||
        t.contains('任天堂') ||
        t.contains('switch') ||
        t.contains('ps5')) {
      return '数码3C';
    }

    if (t.contains('书') ||
        t.contains('考研') ||
        t.contains('真题') ||
        t.contains('教材') ||
        t.contains('课本') ||
        t.contains('小说') ||
        t.contains('绘本') ||
        t.contains('资料')) {
      return '二手书籍';
    }

    if (t.contains('手办') ||
        t.contains('盲盒') ||
        t.contains('泡泡玛特') ||
        t.contains('高达') ||
        t.contains('模型') ||
        t.contains('谷子') ||
        t.contains('徽章') ||
        t.contains('吧唧') ||
        t.contains('乐高') ||
        t.contains('潮玩')) {
      return '潮玩模玩';
    }

    if (t.contains('衣') ||
        t.contains('裤') ||
        t.contains('鞋') ||
        t.contains('包') ||
        t.contains('裙') ||
        t.contains('外套') ||
        t.contains('羽绒服') ||
        t.contains('耐克') ||
        t.contains('阿迪') ||
        t.contains('lululemon')) {
      return '服饰鞋包';
    }

    if (t.contains('口红') ||
        t.contains('香水') ||
        t.contains('面膜') ||
        t.contains('精华') ||
        t.contains('粉底') ||
        t.contains('美妆')) {
      return '美妆个护';
    }

    if (t.contains('童装') ||
        t.contains('婴儿') ||
        t.contains('奶粉') ||
        t.contains('推车') ||
        t.contains('母婴')) {
      return '母婴闲置';
    }

    if (t.contains('桌') ||
        t.contains('椅') ||
        t.contains('灯') ||
        t.contains('锅') ||
        t.contains('杯') ||
        t.contains('收纳') ||
        t.contains('风扇') ||
        t.contains('电器')) {
      return '家居日用';
    }

    return '综合闲置';
  }

  /// 解析闲鱼前端状态文案为标准状态枚举
  static OrderStatus parseOrderStatus(String statusText) {
    final s = statusText.trim();
    if (s.contains('成功') || s.contains('完成') || s.contains('已评价') || s.contains('已确认')) {
      return OrderStatus.completed;
    }
    if (s.contains('待发货') || s.contains('已付款') || s.contains('买家已付款')) {
      return OrderStatus.pendingDelivery;
    }
    if (s.contains('已发货') || s.contains('运输') || s.contains('待收货') || s.contains('等待买家收货')) {
      return OrderStatus.shipped;
    }
    if (s.contains('退款') || s.contains('售后') || s.contains('维权') || s.contains('纠纷')) {
      return OrderStatus.afterSale;
    }
    return OrderStatus.completed;
  }

  /// 从金额文本中提取纯数字（如 "¥4,850.00" -> 4850.0）
  static double parsePrice(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    final str = val.toString().replaceAll('¥', '').replaceAll(',', '').trim();
    return double.tryParse(str) ?? 0.0;
  }

  /// 批量导入抓取到的闲鱼订单，自动去重并入库
  Future<int> importRawOrders(List<Map<String, dynamic>> rawList) async {
    final existingOrders = db.getOrders();
    final existingIds = existingOrders.map((o) => o.orderNumber).toSet();
    final existingTitles = existingOrders.map((o) => o.title.trim()).toSet();

    final List<OrderTransaction> toSave = [];
    final now = DateTime.now();
    final defaultRateStr = db.getSetting('platform_fee_rate', defaultValue: '0.006');
    final defaultRate = double.tryParse(defaultRateStr) ?? 0.006;

    int newCount = 0;

    for (final raw in rawList) {
      final title = (raw['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;

      final orderNo = (raw['orderNumber'] ?? raw['orderId'] ?? '').toString().trim();
      final price = parsePrice(raw['price'] ?? raw['sellingPrice']);
      final statusText = (raw['status'] ?? '交易成功').toString();
      final status = parseOrderStatus(statusText);
      final buyer = (raw['buyer'] ?? raw['buyerNickname'] ?? '').toString().trim();

      // 去重：若订单号或完全相同的标题已存在，则更新状态或跳过
      if (orderNo.isNotEmpty && existingIds.contains(orderNo)) {
        continue;
      }
      if (orderNo.isEmpty && existingTitles.contains(title)) {
        continue;
      }

      final cat = classifyCategory(title);

      final order = OrderTransaction(
        title: title,
        orderNumber: orderNo,
        category: cat,
        buyerNickname: buyer,
        notes: '由闲鱼一键同步导入',
        status: status,
        costPrice: 0.0, // 初始进价设为 0，后续可单笔修改或按利润率批量补充
        sellingPrice: price,
        shippingFee: 0.0,
        packagingFee: 0.0,
        platformFeeRate: defaultRate,
        createdAt: now,
      );

      toSave.add(order);
      newCount++;
    }

    if (toSave.isNotEmpty) {
      await db.saveOrders(toSave);
    }

    // 记录同步时间
    await db.setSetting('last_sync_time', DateTime.now().toString().substring(0, 16));
    await db.setSetting('xianyu_connected', 'true');

    return newCount;
  }
}
