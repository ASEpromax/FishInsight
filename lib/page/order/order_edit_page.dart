import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fishinsight/database/database_helper.dart';
import 'package:fishinsight/design/app_theme.dart';
import 'package:fishinsight/model/order_transaction.dart';

class OrderEditPage extends StatefulWidget {
  final OrderTransaction? order;

  const OrderEditPage({super.key, this.order});

  @override
  State<OrderEditPage> createState() => _OrderEditPageState();
}

class _OrderEditPageState extends State<OrderEditPage> {
  DatabaseHelper get _db => Get.find<DatabaseHelper>();

  final _formKey = GlobalKey<FormState>();
  late String _title;
  late String _orderNumber;
  late String _category;
  late String _buyerNickname;
  late String _notes;
  late OrderStatus _status;

  late double _costPrice;
  late double _sellingPrice;
  late double _shippingFee;
  late double _packagingFee;
  late double _platformFeeRate;
  late double _otherExpense;

  final List<String> _commonCategories = [
    '数码3C',
    '二手书籍',
    '潮玩模玩',
    '服饰鞋包',
    '母婴闲置',
    '美妆个护',
    '家居日用',
    '办公文具',
    '其它闲置'
  ];

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    _title = o?.title ?? '';
    _orderNumber = o?.orderNumber ?? '';
    _category = o?.category ?? '数码3C';
    _buyerNickname = o?.buyerNickname ?? '';
    _notes = o?.notes ?? '';
    _status = o?.status ?? OrderStatus.pendingDelivery;

    _costPrice = o?.costPrice ?? 0.0;
    _sellingPrice = o?.sellingPrice ?? 0.0;
    _shippingFee = o?.shippingFee ?? 0.0;
    _packagingFee = o?.packagingFee ?? 0.0;
    _platformFeeRate = o?.platformFeeRate ?? 0.006;
    _otherExpense = o?.otherExpense ?? 0.0;
  }

  // 实时衍生计算
  double get _platformFee => _sellingPrice * _platformFeeRate;
  double get _totalCost => _costPrice + _shippingFee + _packagingFee + _platformFee + _otherExpense;
  double get _netProfit => _sellingPrice - _totalCost;
  double get _profitMargin => _sellingPrice > 0 ? (_netProfit / _sellingPrice) * 100 : 0.0;
  double get _roi => _costPrice > 0 ? (_netProfit / _costPrice) * 100 : 0.0;

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final order = OrderTransaction(
      id: widget.order?.id,
      title: _title.trim(),
      orderNumber: _orderNumber.trim(),
      category: _category,
      buyerNickname: _buyerNickname.trim(),
      notes: _notes.trim(),
      createdAt: widget.order?.createdAt ?? DateTime.now(),
      status: _status,
      costPrice: _costPrice,
      sellingPrice: _sellingPrice,
      shippingFee: _shippingFee,
      packagingFee: _packagingFee,
      platformFeeRate: _platformFeeRate,
      otherExpense: _otherExpense,
    );

    await _db.saveOrder(order);
    Get.back(result: true);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.order != null;

    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: AppBar(
        title: Text(isEditing ? '编辑闲鱼订单' : '新增闲鱼订单记账'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded, color: AppTheme.primary),
            label: const Text('保存', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      bottomNavigationBar: _buildLiveProfitBottomBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. 商品与买家基础信息
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('商品与交易基础', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _title,
                      decoration: const InputDecoration(
                        labelText: '商品标题 *',
                        hintText: '如：Sony A6400 机身、iPad mini 6',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? '请输入商品标题' : null,
                      onSaved: (v) => _title = v ?? '',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _orderNumber,
                            decoration: const InputDecoration(
                              labelText: '订单号/宝贝ID',
                              hintText: '选填',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSaved: (v) => _orderNumber = v ?? '',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _commonCategories.contains(_category) ? _category : _commonCategories.first,
                            decoration: const InputDecoration(
                              labelText: '品类分类',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _commonCategories.map((c) {
                              return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)));
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _category = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _buyerNickname,
                            decoration: const InputDecoration(
                              labelText: '买家昵称',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSaved: (v) => _buyerNickname = v ?? '',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<OrderStatus>(
                            value: _status,
                            decoration: const InputDecoration(
                              labelText: '履约状态',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: OrderStatus.values.map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text(s.label, style: TextStyle(color: Color(s.colorValue), fontSize: 13, fontWeight: FontWeight.bold)),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _status = v);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. 财务要素与收支计算 (核心)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('财务精算要素 (元)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                          child: const Text('实时核算纯利', style: TextStyle(color: Color(0xFF2563EB), fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMoneyField(
                            label: '实际售价 (成交价)',
                            initial: _sellingPrice,
                            color: const Color(0xFF10B981),
                            onChanged: (v) => setState(() => _sellingPrice = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMoneyField(
                            label: '进货成本 (进价)',
                            initial: _costPrice,
                            color: const Color(0xFF3B82F6),
                            onChanged: (v) => setState(() => _costPrice = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMoneyField(
                            label: '运费支出',
                            initial: _shippingFee,
                            onChanged: (v) => setState(() => _shippingFee = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMoneyField(
                            label: '包材耗材杂费',
                            initial: _packagingFee,
                            onChanged: (v) => setState(() => _packagingFee = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: (_platformFeeRate * 100).toStringAsFixed(1),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: '闲鱼扣点 (%)',
                              helperText: '扣点: ${AppTheme.formatMoney(_platformFee)}',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (v) {
                              final rate = double.tryParse(v) ?? 0.6;
                              setState(() => _platformFeeRate = rate / 100);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMoneyField(
                            label: '其它损耗',
                            initial: _otherExpense,
                            onChanged: (v) => setState(() => _otherExpense = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. 沟通备忘与追踪记录
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('沟通事项与备忘', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _notes,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: '如：买家要求顺丰特快、送赠品、签收后提醒返评等...',
                        border: OutlineInputBorder(),
                      ),
                      onSaved: (v) => _notes = v ?? '',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildMoneyField({
    required String label,
    required double initial,
    Color? color,
    required ValueChanged<double> onChanged,
  }) {
    return TextFormField(
      initialValue: initial > 0 ? initial.toStringAsFixed(2) : '',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '¥ ',
        border: const OutlineInputBorder(),
        isDense: true,
        labelStyle: color != null ? TextStyle(color: color, fontWeight: FontWeight.bold) : null,
      ),
      onChanged: (val) {
        final num = double.tryParse(val) ?? 0.0;
        onChanged(num);
      },
    );
  }

  /// 底部实时利润试算条
  Widget _buildLiveProfitBottomBar() {
    final isProfit = _netProfit >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('预估单笔纯利润', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(
                  (isProfit ? '+' : '') + AppTheme.formatMoney(_netProfit),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '毛利率 ${AppTheme.formatPercent(_profitMargin)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 2),
                Text(
                  'ROI ${AppTheme.formatPercent(_roi)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
