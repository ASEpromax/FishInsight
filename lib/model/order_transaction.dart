import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 闲鱼订单履约状态
enum OrderStatus {
  pendingDelivery, // 待发货
  shipped, // 已发货（待买家签收与确认收货）
  completed, // 交易成功（款项已到账）
  afterSale, // 售后维权/退换中
}

extension OrderStatusExt on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pendingDelivery:
        return '待发货';
      case OrderStatus.shipped:
        return '已发货';
      case OrderStatus.completed:
        return '已完成';
      case OrderStatus.afterSale:
        return '售后中';
    }
  }

  int get colorValue {
    switch (this) {
      case OrderStatus.pendingDelivery:
        return 0xFFF59E0B; // 琥珀黄（提示需履约）
      case OrderStatus.shipped:
        return 0xFF3B82F6; // 科技蓝（运输流转）
      case OrderStatus.completed:
        return 0xFF10B981; // 翡翠绿（落袋为安）
      case OrderStatus.afterSale:
        return 0xFFEF4444; // 警戒红（售后纠纷）
    }
  }
}

/// 知鱼 (FishInsight) 核心订单与财务交易模型
class OrderTransaction {
  final String id;
  String orderNumber; // 闲鱼订单号或商品ID
  String title; // 商品标题
  String category; // 品类（如：数码3C、二手书籍、潮玩模玩、服饰鞋包、母婴闲置等）
  String buyerNickname; // 买家昵称
  String notes; // 备注与沟通事项
  DateTime createdAt; // 录入/拍下时间
  DateTime? shippedAt; // 发货时间
  DateTime? completedAt; // 确认收货时间
  DateTime? deliveryDeadline; // 承诺发货截止时间（默认拍下后48小时）
  OrderStatus status;

  // ===== 财务要素 (单位：元) =====
  double costPrice; // 进货底价 / 购入成本
  double sellingPrice; // 闲鱼实际成交价
  double shippingFee; // 快递运费支出（自费发货则为成本）
  double packagingFee; // 纸箱、气泡垫等耗材杂费
  double platformFeeRate; // 闲鱼软件服务费扣点比例（如 0.006 代表千分之六）
  double otherExpense; // 其它损耗或杂费

  OrderTransaction({
    String? id,
    required this.title,
    this.orderNumber = '',
    this.category = '综合闲置',
    this.buyerNickname = '',
    this.notes = '',
    DateTime? createdAt,
    this.shippedAt,
    this.completedAt,
    DateTime? deliveryDeadline,
    this.status = OrderStatus.pendingDelivery,
    this.costPrice = 0.0,
    this.sellingPrice = 0.0,
    this.shippingFee = 0.0,
    this.packagingFee = 0.0,
    this.platformFeeRate = 0.006,
    this.otherExpense = 0.0,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        deliveryDeadline = deliveryDeadline ??
            (createdAt ?? DateTime.now()).add(const Duration(hours: 48));

  /// 平台服务费
  double get platformFee => sellingPrice * platformFeeRate;

  /// 全要素总成本
  double get totalCost =>
      costPrice + shippingFee + packagingFee + platformFee + otherExpense;

  /// 单笔纯毛利
  double get netProfit => sellingPrice - totalCost;

  /// 毛利率 (%)
  double get profitMargin =>
      sellingPrice > 0 ? (netProfit / sellingPrice) * 100 : 0.0;

  /// 投资回报率 ROI (%)
  double get roi => costPrice > 0 ? (netProfit / costPrice) * 100 : 0.0;

  /// 是否发货超时预警
  bool get isDeliveryUrgent {
    if (status != OrderStatus.pendingDelivery) return false;
    final ddl = deliveryDeadline;
    if (ddl == null) return false;
    return ddl.difference(DateTime.now()).inHours <= 12;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNumber': orderNumber,
        'title': title,
        'category': category,
        'buyerNickname': buyerNickname,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'shippedAt': shippedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'deliveryDeadline': deliveryDeadline?.toIso8601String(),
        'status': status.index,
        'costPrice': costPrice,
        'sellingPrice': sellingPrice,
        'shippingFee': shippingFee,
        'packagingFee': packagingFee,
        'platformFeeRate': platformFeeRate,
        'otherExpense': otherExpense,
      };

  factory OrderTransaction.fromJson(Map<String, dynamic> json) {
    return OrderTransaction(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '未命名闲置',
      orderNumber: json['orderNumber'] as String? ?? '',
      category: json['category'] as String? ?? '综合闲置',
      buyerNickname: json['buyerNickname'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      shippedAt: json['shippedAt'] != null
          ? DateTime.tryParse(json['shippedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      deliveryDeadline: json['deliveryDeadline'] != null
          ? DateTime.tryParse(json['deliveryDeadline'] as String)
          : null,
      status: json['status'] != null && json['status'] is int
          ? OrderStatus.values[json['status'] as int]
          : OrderStatus.pendingDelivery,
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      shippingFee: (json['shippingFee'] as num?)?.toDouble() ?? 0.0,
      packagingFee: (json['packagingFee'] as num?)?.toDouble() ?? 0.0,
      platformFeeRate: (json['platformFeeRate'] as num?)?.toDouble() ?? 0.006,
      otherExpense: (json['otherExpense'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String serialize() => jsonEncode(toJson());
  static OrderTransaction deserialize(String str) =>
      OrderTransaction.fromJson(jsonDecode(str) as Map<String, dynamic>);
}
