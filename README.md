# 知鱼 (FishInsight)

> “子非鱼，安知鱼之乐？子非我，安知我不知鱼之乐？”  
> ——《庄子·秋水》

[![GitHub Release](https://img.shields.io/github/v/release/ASEpromax/FishInsight?color=orange&label=Release&logo=github)](https://github.com/ASEpromax/FishInsight/releases/latest)
[![Fast Download](https://img.shields.io/badge/⚡%20国内高速下载-APK%20(v1.0.0)-brightgreen?logo=android)](https://ghfast.top/https://github.com/ASEpromax/FishInsight/releases/download/v1.0.0/FishInsight-v1.0.0-arm64.apk)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

### 📲 立即下载安装包 (v1.0.0)
- ⚡ **[国内高速直链下载（免魔法·推荐）](https://ghfast.top/https://github.com/ASEpromax/FishInsight/releases/download/v1.0.0/FishInsight-v1.0.0-arm64.apk)** (20.6MB)
- 🌐 **[GitHub 官方 Releases 详情页](https://github.com/ASEpromax/FishInsight/releases/tag/v1.0.0)**

**知鱼 (FishInsight)** 是一套面向闲鱼个人卖家、二手电商创作者与捡漏选品玩家的**商业智能与财务分析系统（BI & Analytics System）**。  
以数据分析为核心、订单履约流程为骨架，帮助卖家看清每一笔账，抓住每一个赚钱品类。

---

## 核心功能矩阵

### 1. 📊 商业财务多维大盘透视 (Business & Financial Analytics)
- **核心收益 Hero 看板**：累计销售流水、全要素总成本支出、实赚净毛利、综合毛利率与投资回报率 ROI。
- **近 7 天 / 近 30 天收支走势分析**：双色柱状图直观对比每日销售额与净利润产出。
- **全要素成本构成透视**：进货成本、快递运费、闲鱼平台服务费（扣点）、包装耗材占比一览无余。
- **品类吸金力排行榜**：按净利润贡献度自动排名，直观呈现不同品类的单均利润与 ROI。

### 2. 📦 闲鱼订单履约工作台 (Fulfillment Cockpit)
- **状态流转管线**：待发货（超时预警）、已发货（待签收）、已完成、售后纠纷全流程掌控。
- **全要素财务精算器**：录单或改单时，实时动态计算闲鱼平台扣点（默认 0.6%）、全要素总成本、单笔实赚净毛利及毛利率。
- **快速检索与筛选**：支持按商品标题、买家昵称、订单编号或品类进行实时模糊搜索。

### 3. 💡 知鱼 AI 商业参谋 (DeepSeek Copilot)
- **一键经营诊断**：将本地真实的交易流水、品类分布与财务指标打包输入大模型，一键生成多维诊断报告。
- **深度透视**：评估经营健康度、挖掘暴利黄金品类、警示运费或包材侵蚀风险，并提供下一周的具体行动清单。

### 4. 🛡️ 隐私与数据安全
- **100% 本地存储**：采用轻量高速的 Hive 数据库，所有敏感交易与进货底牌仅保存在设备本地。
- **支持数据备份**：一键导出 JSON 备份，数据完全归您所有。

---

## 技术架构

- **前端客户端**：Flutter 3 / Dart（GetX 状态管理、Hive 本地持久化、Material 3 商业设计语言）
- **构建与发布**：GitHub Actions 云端自动化打包，推送即可自动生成 Release APK
- **AI 智能引擎**：DeepSeek Chat API / 本地规则专家双模式

---

## 快速构建与发布

1. 本地代码提交后，直接双击运行 `推送到GitHub.bat`；
2. GitHub Actions 将自动执行编译、语法检测与打包；
3. 构建完成后，在 GitHub Releases 页面直接下载 `FishInsight-arm64-release.apk` 即可安装使用。
