# DPoker GTO 工具 — 技术架构 & UI 设计方案 V1.0

---

## 一、技术架构总览

```
┌─────────────────────────────────────────────────────┐
│                    浏览器端（Browser）                  │
│                                                       │
│  ┌────────────────┐    ┌──────────────────────────┐  │
│  │   UI 层        │    │    计算层（Web Worker）     │  │
│  │  React + Vite  │◄──►│  CFR Solver (WASM/JS)    │  │
│  │  Tailwind CSS  │    │  Equity Calculator        │  │
│  │  Framer Motion │    │  Lookup Table Query       │  │
│  └────────────────┘    └──────────────────────────┘  │
│           │                        │                  │
│           ▼                        ▼                  │
│  ┌────────────────┐    ┌──────────────────────────┐  │
│  │  状态管理       │    │    本地数据层              │  │
│  │  Zustand       │    │  IndexedDB（历史记录）      │  │
│  │                │    │  PWA Cache（查找表）        │  │
│  └────────────────┘    └──────────────────────────┘  │
└─────────────────────────────────────────────────────┘
                          │
                          ▼ （可选云服务 V2.0）
              ┌───────────────────────┐
              │    后端（可选）         │
              │  Cloudflare Workers   │
              │  Supabase（用户数据）   │
              └───────────────────────┘
```

**核心架构决策：以客户端为主，最大化降低延迟**
- GTO 计算完全在浏览器端执行（Web Worker），无网络 RTT
- 预计算查找表打包进 PWA Cache，支持离线使用
- V1.0 无需后端，V2.0 可选接入云端保存历史

---

## 二、前端技术选型

| 层次 | 技术选型 | 选型理由 |
| --- | --- | --- |
| 框架 | React 18 + Vite 5 | 组件化、生态成熟、构建快 |
| 样式 | Tailwind CSS 3 | 快速原型、设计系统一致性 |
| 动画 | Framer Motion | 牌面选择动效、结果渐入动效 |
| 状态管理 | Zustand | 轻量，适合中小型应用 |
| 图表 | Recharts | 频率条形图、权益圆环图 |
| 构建工具 | Vite + Rollup | 首屏 chunk 分割，按需加载查找表 |
| PWA | vite-plugin-pwa | 离线缓存查找表 |
| 计算线程 | Web Worker API | CFR 求解不阻塞主线程 |

---

## 三、GTO 计算引擎设计

### 3.1 数据结构

```typescript
// 手牌表示
type Card = {
  rank: 'A'|'K'|'Q'|'J'|'T'|'9'|'8'|'7'|'6'|'5'|'4'|'3'|'2';
  suit: 's'|'h'|'d'|'c';  // spade/heart/diamond/club
};

// 牌局状态
type GameState = {
  heroCards: [Card, Card];
  boardCards: Card[];       // 0~5张
  street: 'preflop'|'flop'|'turn'|'river';
  position: 'BTN'|'CO'|'HJ'|'UTG1'|'SB'|'BB';
  effectiveStack: number;   // 单位 BB
  potSize: number;          // 单位 BB
  facingAction: FacingAction;
  opponentCount: 1|2|3;
};

// 策略输出
type GTOStrategy = {
  fold:  { freq: number };
  call:  { freq: number };
  raise: { freq: number; sizings: number[] }; // sizings 单位 BB
  equity: number;       // 0~1
  confidence: 'table'|'solver'|'approximate';
  explanation: string;  // 新手解释文本
};
```

### 3.2 预计算查找表结构

```
lookup/
├── preflop/
│   ├── RFI.json          # 开放加注范围（按位置）
│   ├── vs_RFI_call.json  # 面对 RFI 的跟注范围
│   ├── vs_RFI_3bet.json  # 3-Bet 范围
│   └── vs_3bet.json      # 面对 3-Bet 的策略
├── flop/
│   ├── texture_index.json    # 板面纹理分类
│   └── strategies/           # 按板面类型+位置+行动索引
│       ├── dry_board_btn_bb.json
│       └── ...（约 500 个文件，总计 ~8MB 压缩后）
└── postflop_approximate/
    └── equity_tables/        # 各手牌类型权益速查表
```

**板面纹理分类（减少存储量）：**
翻后不存储全部 C(52,3)=22,100 种翻牌组合，而是将板面归类为约 30 种纹理类型（Texture），例如：
- `rainbow_dry`：彩虹无连牌（A72r）
- `monotone`：同花三张（KQ9s）
- `double_paired`：两对板（AA7）
- `coordinated_wet`：高度协调（JT9s）

查询时按纹理匹配，误差在可接受范围内。

### 3.3 实时 CFR 求解（翻后）

```typescript
// Web Worker 中运行
class SimplifiedCFRSolver {
  private iterations = 1000;
  
  solve(state: GameState, villainRange: HandRange): GTOStrategy {
    // 1. 构建博弈树（简化版，限制深度为3层）
    const tree = buildGameTree(state, this.maxDepth = 3);
    
    // 2. CFR 迭代
    for (let i = 0; i < this.iterations; i++) {
      this.cfr(tree, state, villainRange, 1, 1);
    }
    
    // 3. 提取均衡策略
    return tree.root.averageStrategy;
  }
  
  private cfr(node, state, range, reachProb_h, reachProb_v): number {
    // 标准 CFR 递归实现
    // 反事实遗憾累积 → 策略更新
  }
}
```

权益计算使用 Monte Carlo 模拟（Web Worker 中，10,000 次采样，耗时 < 100ms）：

```typescript
function calculateEquity(heroCards: Card[], boardCards: Card[], villainRange: HandRange): number {
  let wins = 0;
  const samples = 10000;
  for (let i = 0; i < samples; i++) {
    const villainHand = sampleFromRange(villainRange);
    const runout = dealRunout(heroCards, boardCards, villainHand);
    if (evaluateHand(heroCards, runout) > evaluateHand(villainHand, runout)) wins++;
  }
  return wins / samples;
}
```

---

## 四、UI 设计规范

### 4.1 设计风格定位

**关键词：** 暗色高级 / 扑克桌质感 / 数据可视化 / 简约克制

**参考风格：** Linear App 的信息密度 + Vercel Dashboard 的暗色系

### 4.2 配色系统

```css
/* 主色调：深色基底，扑克桌绿色点缀 */
--bg-primary:    #0F1117;  /* 主背景 */
--bg-secondary:  #1A1D2E;  /* 卡片/面板背景 */
--bg-tertiary:   #252838;  /* 次级面板 */
--border:        #2D3048;  /* 边框 */

/* 品牌色 */
--accent:        #00D4A4;  /* 薄荷绿：主要行动按钮 */
--accent-dim:    #00D4A420; /* 低饱和度背景 */

/* 牌面花色 */
--suit-red:      #F87171;  /* ♥♦ 红色花色 */
--suit-black:    #E2E8F0;  /* ♠♣ 黑色花色（深色背景下用浅色） */

/* 行动颜色 */
--action-fold:   #EF4444;  /* 弃牌：红 */
--action-call:   #F59E0B;  /* 跟注：黄 */
--action-raise:  #10B981;  /* 加注：绿 */
--action-mixed:  #8B5CF6;  /* 混合：紫 */

/* 文字 */
--text-primary:  #F1F5F9;
--text-secondary:#94A3B8;
--text-muted:    #475569;
```

### 4.3 字体

```css
/* 标题/数字：等宽感强，扑克气质 */
font-family: 'Space Grotesk', 'Inter', sans-serif;

/* 牌面数字/字母：清晰易读 */
font-family: 'JetBrains Mono', monospace;

/* 大比例数字（频率%，权益%）：*/
font-size: 48px;
font-weight: 700;
font-variant-numeric: tabular-nums;
```

### 4.4 核心组件规范

**扑克牌卡片组件（Card Component）**

```
┌──────┐
│ A    │   尺寸：选牌格 40×56px / 手牌展示 64×88px
│  ♠   │   圆角：6px
│    A │   已选：accent 边框 + 白色背景
└──────┘   置灰：opacity: 30%，cursor: not-allowed
```

花色颜色：♥♦ 用 `--suit-red`，♠♣ 用 `--suit-black`

**位置选择器（Position Selector）**

可视化 6 座牌桌 SVG 组件，每个位置为可点击热区（40×40px），选中后：
- 背景填充 `--accent`
- 文字变深色
- 轻微缩放动效 `scale(1.05)`

**行动频率条（Frequency Bar）**

```
┌────────────────────────────────────┐
│ FOLD   █████████░░░░░░░░░  45%     │
│ CALL   ████░░░░░░░░░░░░░░  23%     │
│ RAISE  ████████░░░░░░░░░░  32%  →2.5x│
└────────────────────────────────────┘
```

条宽用 CSS transition 动画渐入（duration: 600ms, easing: ease-out）。

### 4.5 页面布局规范

**桌面端（≥1024px）三栏布局：**

```
┌──────────────────────────────────────────────────────┐
│  DPoker GTO                              [设置] [登录] │
├─────────────────┬──────────────────┬─────────────────┤
│                 │                  │                  │
│  输入区（380px） │  结果区（flex-1）  │  历史区（280px）  │
│                 │                  │                  │
│  ① 街道选择     │  主行动建议       │  最近记录 ×20    │
│  ② 牌面输入     │  频率条形图       │                  │
│  ③ 参数设置     │  权益圆环         │                  │
│  [计算按钮]     │  新手解释卡片     │                  │
│                 │  [进阶信息↓]     │                  │
│                 │                  │                  │
└─────────────────┴──────────────────┴─────────────────┘
```

**移动端（<768px）上下折叠：**

```
┌──────────────────────┐
│  DPoker GTO    [菜单] │
├──────────────────────┤
│  街道: [F][Fl][T][R]  │
│  ──── 52张牌格 ────   │
│  （4行×13列紧凑排列）  │
│  手牌: [A♠] [K♠]     │
│  ──── 参数区 ────     │
│  位置: [牌桌图]        │
│  [计算 GTO 策略]       │
├──────────────────────┤
│  结果展示区            │
│  RAISE 32%            │
│  频率条 / 权益 / 解释  │
└──────────────────────┘
```

---

## 五、项目目录结构

```
DPoker/
├── public/
│   ├── lookup/              # 预计算查找表（JSON，PWA缓存）
│   │   ├── preflop/
│   │   └── flop/
│   └── manifest.json        # PWA 配置
├── src/
│   ├── components/
│   │   ├── CardGrid/        # 52张牌格选择器
│   │   ├── PositionSelector/# 可视化位置选择
│   │   ├── StreetSelector/  # 街道标签
│   │   ├── ParamPanel/      # 参数设置面板
│   │   ├── ResultPanel/     # 策略结果展示
│   │   ├── FrequencyBar/    # 行动频率条
│   │   ├── EquityGauge/     # 权益圆环图
│   │   └── HistoryList/     # 历史记录列表
│   ├── engine/
│   │   ├── lookup.ts        # 查找表加载与查询
│   │   ├── cfr.ts           # CFR 求解器
│   │   ├── equity.ts        # Monte Carlo 权益计算
│   │   ├── handEval.ts      # 牌型评估（7张牌最优5张）
│   │   ├── ranges.ts        # 区间定义与操作
│   │   └── solver.worker.ts # Web Worker 入口
│   ├── store/
│   │   └── gameStore.ts     # Zustand 全局状态
│   ├── utils/
│   │   ├── cardUtils.ts     # 牌面解析、花色处理
│   │   └── formatters.ts    # 频率格式化、文本生成
│   ├── App.tsx
│   └── main.tsx
├── docs/
│   ├── PRD_DPoker_GTO_v1.0.md    # 产品需求文档
│   └── ARCH_DPoker_v1.0.md       # 本文档
├── package.json
└── vite.config.ts
```

---

## 六、开发里程碑

### V1.0 MVP（预计 4 周）

| 周次 | 目标 | 交付物 |
| --- | --- | --- |
| Week 1 | 基础框架 + 牌面输入 UI | CardGrid、PositionSelector 组件可用 |
| Week 2 | 计算引擎 + 查找表 | Pre-Flop 查表 100% 覆盖，翻后权益计算 |
| Week 3 | 结果展示 + 动效 | ResultPanel、FrequencyBar、EquityGauge 完成 |
| Week 4 | 整合测试 + PWA + 部署 | Vercel/Cloudflare 部署，离线可用 |

### V1.5（+2 周）

- 历史记录（IndexedDB）
- 对手区间自定义（区间网格选择器）
- 新手解释文本优化（覆盖更多情境）

### V2.0（+4 周）

- 用户登录（Supabase Auth）
- 云端历史同步
- 翻后 CFR 精度提升（迭代次数增加 + WASM 加速）
- 移动端 PWA 完整支持

---

## 七、GTO 准确性保障措施

| 场景 | 保障方案 |
| --- | --- |
| Pre-Flop 策略 | 使用公开发布的标准 GTO 解（如 GTO Wizard 公开数据），手工校验 |
| 翻后权益 | Monte Carlo 对比 PokerStove 验证，误差控制在 ±2% 内 |
| 翻后策略 | CFR 结果与 PioSOLVER 参考解对比，标注近似误差 |
| 用户提示 | 界面始终标注当前结果的置信度（查表/近似求解），避免误导新手 |
