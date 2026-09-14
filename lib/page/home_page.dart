import 'package:flutter/material.dart';
import 'package:fishinsight/design/app_theme.dart';
import 'package:fishinsight/page/finance/finance_dashboard_page.dart';
import 'package:fishinsight/page/order/order_list_page.dart';
import 'package:fishinsight/page/ai/ai_advisor_page.dart';
import 'package:fishinsight/page/option/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    FinanceDashboardPage(),
    OrderListPage(),
    AiAdvisorPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primary.withOpacity(0.08),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: AppTheme.primary),
            label: '商业透视',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded, color: AppTheme.primary),
            label: '履约工作台',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1)),
            label: '商业参谋',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.tune_rounded, color: AppTheme.primary),
            label: '系统设置',
          ),
        ],
      ),
    );
  }
}
