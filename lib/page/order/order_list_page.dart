import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fishinsight/database/database_helper.dart';
import 'package:fishinsight/design/app_theme.dart';
import 'package:fishinsight/model/order_transaction.dart';
import 'package:fishinsight/page/order/order_edit_page.dart';

class OrderListPage extends StatefulWidget {
  const OrderListPage({super.key});

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  DatabaseHelper get _db => Get.find<DatabaseHelper>();

  List<OrderTransaction> _allOrders = [];
  String _searchQuery = '';
  OrderStatus? _statusFilter; // null 代表全部

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _allOrders = _db.getOrders();
    });
  }

  List<OrderTransaction> get _filteredOrders {
    return _allOrders.where((o) {
      if (_statusFilter != null && o.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = o.title.toLowerCase().contains(q);
        final matchBuyer = o.buyerNickname.toLowerCase().contains(q);
        final matchOrderNo = o.orderNumber.toLowerCase().contains(q);
        final matchCat = o.category.toLowerCase().contains(q);
        if (!matchTitle && !matchBuyer && !matchOrderNo && !matchCat) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredOrders;

    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: AppBar(
        title: const Text('闲鱼订单履约工作台'),
        actions: [
          IconButton(
            tooltip: '新建订单',
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final res = await Get.to(() => const OrderEditPage());
              if (res == true) _loadData();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索商品名 / 买家 / 订单号 / 品类...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),

          // 2. 状态分栏 Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildStatusTab(null, '全部 (${_allOrders.length})'),
                _buildStatusTab(OrderStatus.pendingDelivery, '待发货'),
                _buildStatusTab(OrderStatus.shipped, '已发货'),
                _buildStatusTab(OrderStatus.completed, '已完成'),
                _buildStatusTab(OrderStatus.afterSale, '售后纠纷'),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // 3. 订单卡片列表
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadData(),
              child: list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('暂无对应状态的订单', style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        return _buildOrderCard(list[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(OrderStatus? status, String label) {
    final active = _statusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: active,
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          color: active ? Colors.white : const Color(0xFF475569),
        ),
        backgroundColor: Colors.white,
        selectedColor: AppTheme.primary,
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: active ? AppTheme.primary : const Color(0xFFE2E8F0)),
        ),
        onSelected: (_) => setState(() => _statusFilter = status),
      ),
    );
  }

  Widget _buildOrderCard(OrderTransaction order) {
    final isProfit = order.netProfit >= 0;
    final statusColor = Color(order.status.colorValue);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final res = await Get.to(() => OrderEditPage(order: order));
          if (res == true) _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：品类标签 + 订单状态 + 菜单
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.category,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (order.buyerNickname.isNotEmpty)
                    Text(
                      '@${order.buyerNickname}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      order.status.label,
                      style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildCardMenu(order),
                ],
              ),
              const SizedBox(height: 10),

              // 中部：商品标题
              Text(
                order.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (order.notes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '备忘: ${order.notes}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),

              // 底部：财务指标透视 (售价、成本、实赚净利)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('实际售价', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 2),
                      Text(
                        AppTheme.formatMoney(order.sellingPrice),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('全要素成本', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 2),
                      Text(
                        AppTheme.formatMoney(order.totalCost),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '净利润 (${AppTheme.formatPercent(order.profitMargin)})',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (isProfit ? '+' : '') + AppTheme.formatMoney(order.netProfit),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardMenu(OrderTransaction order) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded, size: 20, color: Color(0xFF94A3B8)),
      padding: EdgeInsets.zero,
      onSelected: (val) async {
        if (val == 'shipped') {
          order.status = OrderStatus.shipped;
          order.shippedAt = DateTime.now();
          await _db.saveOrder(order);
          _loadData();
        } else if (val == 'completed') {
          order.status = OrderStatus.completed;
          order.completedAt = DateTime.now();
          await _db.saveOrder(order);
          _loadData();
        } else if (val == 'delete') {
          await _db.deleteOrder(order.id);
          _loadData();
        }
      },
      itemBuilder: (context) => [
        if (order.status == OrderStatus.pendingDelivery)
          const PopupMenuItem(value: 'shipped', child: Text('标为已发货')),
        if (order.status == OrderStatus.shipped)
          const PopupMenuItem(value: 'completed', child: Text('标为交易完成')),
        const PopupMenuItem(
          value: 'delete',
          child: Text('删除该订单', style: TextStyle(color: Color(0xFFEF4444))),
        ),
      ],
    );
  }
}
