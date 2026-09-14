import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:fishinsight/database/database_helper.dart';
import 'package:fishinsight/design/app_theme.dart';
import 'package:fishinsight/page/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化本地 Hive 数据库
  final db = DatabaseHelper();
  await db.init();
  Get.put<DatabaseHelper>(db);

  // 2. 沉浸式透明状态栏
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const FishInsightApp());
}

class FishInsightApp extends StatelessWidget {
  const FishInsightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '知鱼 (FishInsight)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      home: const HomePage(),
    );
  }
}
