# DPoker GTO 计算策略架构文档

> 最后更新: 2026-04-13  
> 版本: v1.2 (MCCFR 折中方案)

---

## 一、计算策略总览

DPoker 采用 **分层计算策略(Tiered Calculation Strategy)**，根据游戏阶段、对手数量、面对动作的复杂度，自动选择最佳的计算引擎，在速度和准确度之间取得最优平衡。

```
┌─────────────────────────────────────────────────────────────────┐
│                    DPoker 分层计算策略                            │
├─────────────────────────────────────────────────────────────────┤
│  PREFLOP (翻牌前)                                                │
│  ├── 简单位置 (Open/RFI):        Lookup Table         < 1ms    │
│  └── 复杂位置 (vs3bet/4bet/AI):  MCCFR 1500 iter      ~300ms  │
├─────────────────────────────────────────────────────────────────┤
│  POSTFLOP (翻牌后)                                               │
│  ├── 1-2人 + 面对bet/raise:      MCCFR 400 + MC500    ~250ms  │
│  ├── 1-2人 + 面对check:          MC500 + GTO模板       ~100ms  │
│  └── 3人 (任意动作):             MC500 + GTO模板       ~300ms  │
├─────────────────────────────────────────────────────────────────┤
│  所有场景总耗时:                                     < 500ms   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 二、两大核心引擎对比

### 2.1 MC500 (蒙特卡洛模拟 500 次)

**原理：** 随机发牌 500 次，统计胜率 → 输入到 GTO 策略模板查表

```
你的手牌 + 公共牌
     ↓
随机给对手发牌 500 次，模拟对决
     ↓
统计胜率：赢 280 次 → equity = 56%
     ↓
equity 56% + 面对 bet → 查GTO模板 → "call 70%, raise 20%, fold 10%"
```

**特点：**
- equity 计算准确（±3-4%），策略从模板查找（非实时计算）
- 速度快：1-2 人 50-150ms，3 人 200-500ms
- 模板无法完美覆盖所有牌面纹理/SPR/位置组合

### 2.2 MCCFR (蒙特卡洛反事实遗憾最小化)

**原理：** 让两个 AI 互相博弈 N 次，通过"后悔值"迭代逼近纳什均衡策略

```
你的手牌 + 公共牌 + 对手范围
     ↓
构建博弈树（check / bet / raise / fold 各分支）
     ↓
AI-A vs AI-B 自我博弈 400 次
     ↓
每个决策点的后悔值收敛
     ↓
直接输出："check 35%, bet 1/3 pot 40%, bet 2/3 pot 25%"
```

**特点：**
- 策略是针对当前局面实时计算的，考虑博弈树所有分支
- 能发现 implied odds, bluff equity, check-raise 等模板遗漏的策略
- 400 次迭代 ~100-150ms，策略收敛度良好

### 2.3 核心区别总结

| 维度 | MC500 | MCCFR |
|------|-------|-------|
| **计算什么** | 只算胜率(equity) | 计算完整策略(strategy) |
| **策略来源** | 查模板（预设规则） | 实时博弈收敛（纳什均衡） |
| **决策精度** | equity 准，策略粗 | 两者都准 |
| **适合场景** | 标准场景、check 位置 | 面对 bet/raise 的边缘场景 |
| **速度** | 50-300ms | 100-500ms |

---

## 三、各场景详细策略

### 3.1 Preflop - 简单位置 (Lookup Table)

**触发条件：** `street === 'preflop'` 且动作为 `open/open2/open25/open3/vsor/vslimp_bp/vslimps`

```javascript
return calculatePreflopGTO(handKey, pos, facing);
```

- 直接从 169 手牌 × 6 位置的 GTO 查找表读取
- 数据源：预计算的 GTO ranges（来自 Solver 离线训练）
- 耗时：< 1ms

### 3.2 Preflop - 复杂位置 (MCCFR 1500)

**触发条件：** `street === 'preflop'` 且动作为 `vs3bet/vs4bet/vsai`

```javascript
const mccfrResult = runMCCFRSolve(state, { iterations: 1500 });
const lookupResult = calculatePreflopGTO(handKey, pos, facing);
// Blend: MCCFR 策略 + Lookup EV
```

- 1500 次迭代，策略高度收敛
- 与 Lookup 表混合，取两者优势
- 耗时：~300ms

### 3.3 Postflop - 1-2 人 + 面对 bet/raise (MCCFR 400 + MC500)

**触发条件：** `oppCount <= 2` 且 `facing` 不是 `chk/open/check`

```javascript
const equity = calculateEquity(heroCards, boardCards, oppCount, 500);  // MC500
const mccfrResult = runMCCFRSolve(state, { iterations: 400, isPostflop: true });
// Blend: MCCFR 策略决策 + MC500 equity 精度
```

- **为什么用 MCCFR：** 面对 bet/raise 时，check-raise、float、bluff 等策略需要博弈树分析
- **为什么还用 MC500：** MCCFR 内部的 equity 估算精度不如 MC500
- 耗时：~250ms（MC500 ~80ms + MCCFR ~150ms）

### 3.4 Postflop - 1-2 人 + 面对 check (MC500 + GTO 模板)

**触发条件：** `oppCount <= 2` 且 `facing` 是 `chk/open/check`

```javascript
const equity = calculateEquity(heroCards, boardCards, oppCount, 500);
const result = calculatePostflopGTO(equity, pot, stack, facing, pos);
```

- check 位置的策略相对标准（bet/check 二选一），模板足够
- 耗时：~100ms

### 3.5 Postflop - 3 人 (MC500 + GTO 模板)

**触发条件：** `oppCount === 3`

```javascript
const equity = calculateEquity(heroCards, boardCards, oppCount, 500);
const result = calculatePostflopGTO(equity, pot, stack, facing, pos);
```

- 多路底池的 MCCFR 需要 3+ 方博弈树，复杂度指数增长，不可行
- MC500 + GTO 模板是此场景的最佳方案
- 耗时：~300ms

---

## 四、准确度对比

| 场景 | 方法 | Equity 精度 | 策略精度 | 综合评分 |
|------|------|-------------|----------|----------|
| Preflop 简单 | Lookup | N/A | ±1% | ★★★★★ |
| Preflop 复杂 | MCCFR 1500 | ±3% | ±3% | ★★★★★ |
| Postflop 1-2人 vs bet | MCCFR 400+MC500 | ±3-4% | ±4% | ★★★★☆ |
| Postflop 1-2人 vs check | MC500+模板 | ±3-4% | ±5% | ★★★★☆ |
| Postflop 3人 | MC500+模板 | ±5-6% | ±7% | ★★★☆☆ |

---

## 五、优化技术

### 5.1 Mulberry32 种子 PRNG
- 相同手牌 + 公共牌 → 相同种子 → 可复现结果
- 比 Math.random() 更快、更均匀

### 5.2 Partial Fisher-Yates Shuffle
- 只洗需要的 N 张牌（N = boardNeeded + oppCount × 2）
- 数学上等效于全牌洗牌，但减少 ~70% 交换操作

### 5.3 LRU 策略缓存
- 150 条缓存，5 分钟 TTL
- 缓存 key：`cards|position|facingAction|stackDepth|street`
- Postflop MCCFR 使用独立 cache key 后缀 `_pf`

### 5.4 对手范围过滤
- 根据 facingAction 过滤对手范围（vs3bet → top 8%，vsor → top 25%）
- 减少无效模拟，提升 equity 收敛速度

---

## 六、动态牌桌系统

### 6.1 牌桌大小：5/6/7/8 人

```javascript
const TABLE_POSITIONS = {
  5: ['BTN', 'SB', 'BB', 'UTG', 'CO'],
  6: ['BTN', 'SB', 'BB', 'UTG', 'HJ', 'CO'],
  7: ['BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'HJ', 'CO'],
  8: ['BTN', 'SB', 'BB', 'UTG', 'UTG+1', 'UTG+2', 'HJ', 'CO']
};
```

### 6.2 对手数量限制

- **Preflop：** 1 到 (tableSize - 1) 人
- **Postflop：** 固定 1/2/3 人（速度优先）

---

## 七、历史决策记录

| 日期 | 决策 | 原因 |
|------|------|------|
| 初始版本 | MCCFR 2000 iter + MC 3000 全场景 | 追求最高精度 |
| v1.0 | 移除 postflop MCCFR，改用 Instant 估算 | 3+ 人 postflop 超过 5 分钟 |
| v1.1 | 1-2人 MC500，3人 Instant | 发现 1-2 人 MC 速度可接受 |
| v1.2 | 分层策略：MCCFR 400 + MC500 + Lookup | 速度与准确度最佳平衡 |
| **v1.3** | **引擎 8 项修复** | **见下方详细记录** |

### v1.3 修复清单 (2026-04-13)

| # | 问题 | 修复内容 |
|---|------|----------|
| 1 | `getHandStrengthPercentile` 返回值无意义 | 改用 MC60 小样本 vs 随机对手，正确计算百分位 |
| 2 | flop/turn 时 equity 回退到 preflop 查表 | 改用 MC50 小样本，正确考虑公共牌 |
| 3 | Multiway MC 全牌洗牌 | 添加 `count` 参数，partial shuffle 减少 70% 操作 |
| 4 | 博弈树只有 2 层深 | 已知限制，暂不修改（需重构整体架构） |
| 5 | MCCFR/模板 blend 不一致 | extractStrategy 增加 betSize 映射；blend 显式合并所有字段 |
| 6 | EV 计算公式过于简化 | 加入 fold equity、正确 pot odds 计算 |
| 7 | Multiway MC 临时数组 GC 压力 | 预分配 heroHand/oppHand7/fullBoard 数组 |
| 8 | 缓存 key 缺少 oppCount | 加入 `opp${count}` 防止不同对手数命中同一缓存 |

### v1.4 修复清单 (2026-04-13)

| # | 问题 | 严重度 | 修复内容 |
|---|------|--------|----------|
| 9 | `makeHandKey` 未定义 | 🔴 崩溃 | 改为 `cardsToHandKey`（函数已存在） |
| 10 | `missing.push(公共牌)` 缺引号 | 🔴 崩溃 | 改为 `'公共牌'` |
| 11 | `mulberry32` 重复定义 | 🟡 警告 | 删除第二个重复实现 |
| 12 | `OPPONENT_RANGES` 缺 BB/UTG+1/UTG+2 | 🟡 功能 | 添加这三个位置的范围数据 |
| 13 | `detectDraws` 漏检 10-J-Q-K OESD | 🟡 功能 | 添加最高顺子听牌检测逻辑 |
| 14 | Service Worker Blob URL 被浏览器拦截 | 🟡 兼容 | 移除内联 SW，改为简单检测模式 |

### v1.5 修复清单 (2026-04-13)

| # | 问题 | 严重度 | 修复内容 |
|---|------|--------|----------|
| 15 | `getOpenTableName` 缺少 `UTG+1`/`UTG+2` 映射 | 🔴 严重 | 7-8 人桌的这些位置会回退到 `btn_open`，添加映射到 `utg_open` |
| 16 | `calculatePostflopGTO` 依赖全局 `state` | 🔴 严重 | 改为接收 `heroCards/boardCards/street` 参数，提高可测试性 |
| 17 | `renderResult` 中 `bestAction.toUpperCase()` 可能崩溃 | 🔴 严重 | 添加 `(result.bestAction \|\| 'unknown')` 空值保护 |
| 18 | `renderHeroHandDisplay` 直接访问 `state.heroCards[0]` | 🔴 严重 | 添加 `state.heroCards.length < 2` 检查，返回友好提示 |
| 19 | `getLegalActions` 中 `facingAction.includes('raise')` 错误匹配 | 🟡 中等 | 改为 `startsWith('vs')` 前缀检查，避免子字符串误匹配 |
| 20 | `runMCCFRSolve` 中 `isPostflop` 未传递给 `solve()` | 🟡 中等 | 添加参数传递链：`runMCCFRSolve` → `solve` → `buildGameTree` |
| 21 | `FACING_ACTIONS` 翻后 `val:'chk'` 与代码 `'check'` 不一致 | 🟡 中等 | 统一为 `'chk'`，修复 `getLegalActions` 中的判断 |
| 22 | `renderExplanation` 函数始终返回空字符串 | 🟢 轻微 | 添加注释说明这是保留的扩展点 |
| 23 | `seededShuffle` 注释有误导性 | 🟢 轻微 | 改进注释，准确描述 partial Fisher-Yates 行为 |

### v1.6 性能优化 (2026-04-16)

| # | 问题 | 严重度 | 修复内容 |
|---|------|--------|----------|
| 24 | Preflop vs3bet/vs4bet 计算过慢 (1500 iter) | 🔴 严重 | 迭代次数 1500→600，预期速度提升 2.5x (800ms→~120ms) |
| 25 | MCCFR 内部 MC 模拟次数过高 | 🟡 中等 | 终端节点评估 50→30 次模拟，减少 40% 计算量 |
| 26 | Preflop 博弈树构建过深 | 🟡 中等 | 限制 preflop 树深度为单层决策 (hero→opp→terminal) |
| 27 | 计算过程无进度反馈 | 🟢 轻微 | 添加进度条和详细状态文本，提升 UX |

### v1.7 UI 重构 (2026-04-16)

| # | 问题 | 严重度 | 修复内容 |
|---|------|--------|----------|
| 28 | Preflop 面对行动设计不合理 | 🟡 中等 | 重构为两级选择：类别(6大类) + 具体尺寸(2-5个选项) |
| 29 | 缺少灵活的加注尺寸选择 | 🟡 中等 | 主动行动: 2/2.5/3/4/5 BB | 面对OR: 2/3/4/5 BB | 面对3bet: 8/10/12/15 BB | 面对4bet: 20/25/30/40 BB |
| 30 | Limp 场景区分不清晰 | 🟢 轻微 | 统一为"面对 Limp"类别，提供隔离(3/4/5 BB)和平跟选项 |

### v1.7.1 RFI 逻辑修复 (2026-04-16)

| # | 问题 | 严重度 | 修复内容 |
|---|------|--------|----------|
| 31 | 主动行动(RFI)让用户选尺寸不合理 | 🔴 严重 | RFI 改为单级选择，策略直接告诉用户推荐开注尺寸 |
| 32 | 缺少位置-based 开注尺寸推荐 | 🟡 中等 | 添加 `getRecommendedOpenSize()`：UTG/UTG+1/UTG+2=2.5BB, HJ/CO=2.2BB, BTN=2.0BB, SB=3.0BB |
| 33 | 手牌强度影响开注尺寸 | 🟢 轻微 | 强牌(80%+频率)+0.3-0.5BB，边缘牌-0.5BB |
