import 'package:hive_flutter/hive_flutter.dart';
import 'package:fishinsight/model/order_transaction.dart';

class DatabaseHelper {
  static const String ordersBoxName = 'db_orders_v1';
  static const String settingsBoxName = 'db_settings_v1';

  late Box<String> _ordersBox;
  late Box _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _ordersBox = await Hive.openBox<String>(ordersBoxName);
    _settingsBox = await Hive.openBox(settingsBoxName);

    // 如果首次启动且无数据，注入一套逼真的闲鱼初始样本数据，以便直观展示分析系统的图表与统计能力
    if (_ordersBox.isEmpty) {
      await _seedDemoOrders();
    }
  }

  /// 获取所有订单列表（按创建时间倒序）
  List<OrderTransaction> getOrders() {
    final list = <OrderTransaction>[];
    for (final raw in _ordersBox.values) {
      try {
        list.add(OrderTransaction.deserialize(raw));
      } catch (_) {}
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// 保存或更新单个订单
  Future<void> saveOrder(OrderTransaction order) async {
    await _ordersBox.put(order.id, order.serialize());
  }

  /// 批量保存订单
  Future<void> saveOrders(List<OrderTransaction> orders) async {
    final map = <String, String>{};
    for (final o in orders) {
      map[o.id] = o.serialize();
    }
    await _ordersBox.putAll(map);
  }

  /// 删除订单
  Future<void> deleteOrder(String id) async {
    await _ordersBox.delete(id);
  }

  /// 获取设置项
  String getSetting(String key, {String defaultValue = ''}) {
    return _settingsBox.get(key, defaultValue: defaultValue)?.toString() ?? defaultValue;
  }

  /// 保存设置项
  Future<void> setSetting(String key, String value) async {
    await _settingsBox.put(key, value);
  }

  /// 注入演示样本数据
  Future<void> _seedDemoOrders() async {
    final now = DateTime.now();
    final demoList = [
      OrderTransaction(
        title: 'Sony A6400 微单机身 黑色',
        orderNumber: 'XY2026091401',
        category: '数码3C',
        buyerNickname: '摄影小玩家',
        notes: '快门数仅3000，顺丰保价发货',
        createdAt: now.subtract(const Duration(hours: 6)),
        status: OrderStatus.pendingDelivery,
        costPrice: 4200.0,
        sellingPrice: 4850.0,
        shippingFee: 28.0,
        packagingFee: 12.0,
        platformFeeRate: 0.006,
      ),
      OrderTransaction(
        title: 'iPad mini 6 64G 紫色 蜂窝版',
        orderNumber: 'XY2026091302',
        category: '数码3C',
        buyerNickname: '考研上岸小陈',
        notes: '送保护套和电容笔',
        createdAt: now.subtract(const Duration(days: 1, hours: 4)),
        shippedAt: now.subtract(const Duration(hours: 20)),
        status: OrderStatus.shipped,
        costPrice: 2150.0,
        sellingPrice: 2680.0,
        shippingFee: 18.0,
        packagingFee: 8.0,
        platformFeeRate: 0.006,
      ),
      OrderTransaction(
        title: '泡泡玛特 SKULLPANDA 隐藏款手办',
        orderNumber: 'XY2026091203',
        category: '潮玩模玩',
        buyerNickname: '娃圈锦鲤',
        notes: '带盒带卡，全新未拆',
        createdAt: now.subtract(const Duration(days: 2, hours: 2)),
        shippedAt: now.subtract(const Duration(days: 1, hours: 18)),
        completedAt: now.subtract(const Duration(hours: 5)),
        status: OrderStatus.completed,
        costPrice: 89.0,
        sellingPrice: 280.0,
        shippingFee: 10.0,
        packagingFee: 5.0,
        platformFeeRate: 0.006,
      ),
      OrderTransaction(
        title: '2026考研英语历年真题及解析 全新',
        orderNumber: 'XY2026091104',
        category: '二手书籍',
        buyerNickname: '追梦学子',
        notes: '无笔记，极速发货',
        createdAt: now.subtract(const Duration(days: 3, hours: 7)),
        completedAt: now.subtract(const Duration(days: 1)),
        status: OrderStatus.completed,
        costPrice: 15.0,
        sellingPrice: 45.0,
        shippingFee: 8.0,
        packagingFee: 2.0,
        platformFeeRate: 0.006,
      ),
      OrderTransaction(
        title: 'Lululemon Define 瑜伽外套 4码',
        orderNumber: 'XY2026091005',
        category: '服饰鞋包',
        buyerNickname: '晨跑女孩',
        notes: '专柜正品，仅试穿',
        createdAt: now.subtract(const Duration(days: 4, hours: 10)),
        completedAt: now.subtract(const Duration(days: 2)),
        status: OrderStatus.completed,
        costPrice: 380.0,
        sellingPrice: 580.0,
        shippingFee: 12.0,
        packagingFee: 4.0,
        platformFeeRate: 0.006,
      ),
      OrderTransaction(
        title: 'AirPods Pro 2 二代耳机 苹果原装',
        orderNumber: 'XY2026090906',
        category: '数码3C',
        buyerNickname: '科技宅男',
        notes: '在保半年，充电仓有微划痕',
        createdAt: now.subtract(const Duration(days: 5, hours: 12)),
        completedAt: now.subtract(const Duration(days: 3)),
        status: OrderStatus.completed,
        costPrice: 850.0,
        sellingPrice: 1120.0,
        shippingFee: 15.0,
        packagingFee: 5.0,
        platformFeeRate: 0.006,
      ),
    ];

    await saveOrders(demoList);
  }
}
