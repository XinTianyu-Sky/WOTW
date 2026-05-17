# WOTW 数据层

所有游戏数据的 JSON 定义。引擎无关，可直接被任何游戏引擎加载。

## 目录结构

```
assets/data/
├── skills/              # 武学数据
│   ├── skills.schema.json       # 武学 JSON Schema
│   ├── external_skills.json     # 外功（招式武学）
│   ├── internal_skills.json     # 内功（心法）
│   ├── lightness_skills.json    # 轻功（身法）
│   └── status_effects.json     # 异常状态效果
├── items/               # 物品数据
│   ├── items.schema.json        # 物品 JSON Schema
│   └── items.json               # 装备+消耗品+材料+秘籍
├── characters/          # 角色数据
│   ├── characters.schema.json   # 角色 JSON Schema
│   ├── origins.json             # 出身数据
│   ├── companions.json          # 同伴数据
│   └── meridians.json           # 经脉穴位数据
├── quests/              # 任务数据
│   ├── quests.schema.json       # 任务 JSON Schema
│   └── quests.json              # 主线+支线+对话树
└── world/               # 世界数据
    ├── world.schema.json        # 世界 JSON Schema
    └── world.json               # 六大区域+场景+天气+事件
```

## 设计原则

1. **引擎无关**：纯 JSON 数据，不含任何引擎特定代码
2. **Schema 先行**：每个数据模块都有对应的 JSON Schema 定义
3. **ID 引用**：模块间通过字符串 ID 建立关联（如技能引用、物品引用）
4. **数值分离**：数值公式在 Schema 中定义，具体数值在数据文件中
5. **可校验**：使用 `validate_data.py` 自动校验数据完整性

## 数据校验

```bash
# 一次性校验
python scripts/tools/validate_data.py

# 监视模式（开发时使用）
python scripts/tools/validate_data.py --watch
```

## 当前数据规模

| 模块 | 内容 | 数量 |
|------|------|------|
| 外功 | 太极拳、玄冥神掌 | 2套 / 12招 |
| 内功 | 九阳神功、寒冰真气、混元功 | 3套 |
| 轻功 | 草上飞、八步赶蝉、梯云纵、凌波微步等 | 7种 |
| 状态效果 | 中毒/灼烧/冰冻/内伤/破甲/眩晕等 | 15种 |
| 装备 | 武器+防具+饰品 | 10件 |
| 消耗品 | 丹药+Buff道具 | 9种 |
| 材料 | 矿石+草药+木材+布料+宝石 | 16种 |
| 秘籍 | 武学书+残卷 | 4种 |
| 出身 | 将门/书香/遗孤/商贾/药农/乞丐 | 6种 |
| 同伴 | 唐若萱/铁无双/雪灵儿等 | 8名 |
| 经脉 | 任督冲带+阴阳跷+阴阳维 | 8条 / 68穴位 |
| 主线任务 | 第一章（3个节点） | 3条 |
| 支线任务 | 角色支线+门派支线 | 2条 |
| 对话树 | 老乞丐初次对话 | 1棵 |
| 区域 | 中原/蜀中/北冥/东海/南疆/西域 | 6个 |
| 场景 | 城市+野外+地牢+门派 | 16个 |
| 天气 | 晴天→流星雨 | 10种 |
| 全局事件 | 武林大会/铸剑大会/暗月入侵 | 3个 |