# 小游戏分数增加逻辑（Anniversary2025 · 宴会上也要维护风纪！~日奈的热身运动~）

## 核心游戏玩法简介

这是一个**限时点击打击游戏**，目标从地洞中冒出（类似打地鼠），玩家需在其返回前点击击杀。游戏时长 **90 秒**，分为三个阶段，难度递增。

## 核心得分公式（单次击杀得分 = enemyConfig.score）

每个目标类型自带固定的 score 和 combo 加成，仅在**目标被成功击杀（die）**时结算，未击杀（自行返回）不加分也不加连击：

| 目标类型 | 单次击杀得分 | 单次连击加成 | HP（点击次数） | 说明 |
|---------|:----------:|:----------:|:----------:|------|
| Helmet（头盔小兵） | +100 | +1 | 1 | 基础目标，一次点击击杀 |
| Bishop（主教大人） | +300 | +3 | 3 | 需要点击 3 次，击杀分数最高 |
| Makoto（真琴） | +300 | +3 | 1 | 高价值目标，定时出现，一次点击 |
| Fuuka（风纪扣分项） | **-50** | **-2** | 1 | 扣分目标，不要点！ |
| 疯狂模式 Boss（日奈 / Hina） | +20 | - | - | 疯狂模式期间点击 Boss 头像得 20 分/次 |

目标配置表（来自 index-bf443ca4.js）：

    du = {
      Helmet: { score: 100, combo:  1, hp: 1, type: "Helmet" },
      Bishop: { score: 300, combo:  3, hp: 3, type: "Bishop" },
      Fuuka:  { score: -50, combo: -2, hp: 1, type: "Fuuka"  },
      Makoto: { score: 300, combo:  3, hp: 1, type: "Makoto" }
    };
    _s = { duration: 5, score: 20 };  // Fever 时长 & Fever 内 Boss 单次得分

## 分数累加流程

### 总分数累加器

全局变量 `P`（总分）和 `T`（Combo）通过事件总线 `et` 累加：

    let T = 0;   // 当前连击数 Combo
    let P = 0;   // 当前总分 Score

    // ScoreUpdate 事件 -> 累加总分
    et.on(Q.ScoreUpdate, async M => {
      P += M.number;          // 直接累加（Fuuka 为负值会自动扣减）
      P < 0 && (P = 0);       // 分数不低于 0
      c.updateScore({ number: P });
    });

    // ComboUpdate 事件 -> 累加连击
    et.on(Q.ComboUpdate, async M => {
      T += M.number;
      T > Dr && (T = Dr);     // 连击上限 Dr = 30
      c.updateCombo({ number: T });
      T >= Dr ? c.activeFever() : c.deactivateFever();
    });

### 触发时机：当目标被击杀时（die）

每个目标基类有两个回调：`endHandle(killed, enemyConfig)` 和 `afterKillHandle`。
- **killed = true**：HP 归零 die() 时 → 才加分加连击
- **killed = false**：超时未点击自行 returning → 不加分不连击

    handleRoleEnd(s) {
      s.onEnd(async (i, c) => {
        i && (                                         // i = 是否击杀，true 时才加分
          et.emit(Q.ComboUpdate, { number: c.combo }),
          et.emit(Q.ScoreUpdate, { number: c.score })
        );
      });
    }

### 疯狂模式 Boss 加分（Fever 内点 Boss 头像）

    // Boss 头像点击 -> 每次 +20 分（疯狂期间可反复点击快速刷分）
    boss.onClick(() => {
      Wn("crazy");
      et.emit(Q.ScoreUpdate, { number: _s.score });   // _s.score = 20
    });

## 连击与疯狂模式（Combo -> Fever / Crazy）

| 项目 | 数值 | 说明 |
|-----|:---:|------|
| 连击上限 Dr | 30 | 最大 Combo = 30 |
| 疯狂模式触发 | Combo >= 30 且玩家点击 FeverBtn | 连击满 30 激活 Fever 按钮，玩家需主动点击进入 |
| 疯狂模式持续 | _s.duration = 5 秒 | 配置表固定值 |
| Fever 结束后 Combo | 强制重置为 0 | T = 0，需要重新积累 |

    Dr = 30;
    _s = { duration: 5, score: 20 };

    // Combo 达到上限 -> 激活 Fever 按钮（按钮显示脉动动画 feverScaleInfinite）
    T >= Dr ? c.activeFever() : c.deactivateFever();

    // 玩家点击 FeverBtn -> 触发 Q.FeverStart
    s.onclick = () => { et.emit(Q.FeverStart); s.classList.remove("feverScaleInfinite"); };

    // FeverStart -> 主场景暂停，Boss 场景显示，游戏 BGM 音量调小
    et.on(Q.FeverStart, async () => {
      p.pause();            // 暂停主场景生成/动画
      m.show?.();           // 显示 Boss/Hina 画面
      fu("gameBgm", .5, 1); // 游戏 BGM 音量 0.5
    });

    // FeverEnd -> Combo 清零 T=0，回到主场景
    et.on(Q.FeverEnd, async () => { T = 0; ...; c.updateCombo({ number: T }); p.resume(); });

## 三个阶段（关卡）难度切换

总游戏时长 **Tu = 90 秒**，按已经过秒数切换阶段配置：

| 阶段 | 时间段 | ID | waveInterval | min ~ max 数量 | Fuuka 上限 | Bishop 上限 |
|------|:-----:|:-:|:----------:|:----------:|:--------:|:---------:|
| 阶段 1 热身 | 0 ~ 30 秒 | stage0 | 2500 ms (2.5 s) | 3 ~ 4 | 1 | 1 |
| 阶段 2 展开 | 31 ~ 60 秒 | stage1 | 2000 ms (2 s)  | 3 ~ 5 | 1 | 1 |
| 阶段 3 高潮 | 61 ~ 90 秒 | stage2 | 1500 ms (1.5 s)| 4 ~ 6 | 1 | 2 |

    Jg = 31;   // 阶段 2 开始时间（秒）
    Qg = 61;   // 阶段 3 开始时间（秒）
    Tu = 90;   // 游戏总时长（秒）

    Mr = {
      0: { name: "stage0", waveInterval: 2500, minCount: 3, maxCount: 4, fuukaMaxCount: 1, bishopMaxCount: 1 },
      1: { name: "stage1", waveInterval: 2000, minCount: 3, maxCount: 5, fuukaMaxCount: 1, bishopMaxCount: 1 },
      2: { name: "stage2", waveInterval: 1500, minCount: 4, maxCount: 6, fuukaMaxCount: 1, bishopMaxCount: 2 }
    };

切换代码（每次时间回调触发）：

    let m = {};
    elapsed < Jg ? m = { ...Mr[0] }
      : elapsed < Qg ? m = { ...Mr[1] }
      :                m = { ...Mr[2] };
    this.currentStage = m;

### Makoto（高价值 300 分）特殊出现时机

    ps = [
      10 + Math.floor(Math.random() * 30),   // 第 10~40 秒内随机一次
      40 + Math.floor(Math.random() * 20)    // 第 40~60 秒内随机一次
    ];
    // makotoPendingCount += 1，下一波 wave 生成 Makoto；击杀得 300 分 + 3 Combo

## 游戏结束与最高分保存

    function T0(api, payload) {
      const sc = (payload && payload.score) || 0;
      const k = "anniversary2025_highscore";
      const prev = parseInt(localStorage.getItem(k) || "0");
      localStorage.setItem(k, String(Math.max(sc, prev)));
      return { err: { code: 0, msg: "" }, data: { score: sc, high_score: Math.max(sc, prev), rewards: [] } };
    }

## 高分策略总结

1. **优先击杀 Bishop 和 Makoto** — 单次 300 分且 +3 连击，Combo 积累更快（Fuuka 扣 2 连击的影响很大）
2. **避免误点 Fuuka** — 扣 50 分 + 扣 2 连击，Combo 清零直接断送疯狂模式
3. **Combo >= 30 立刻点 Fever 按钮** — 5 秒疯狂期，Boss 每下 +20 分，手速决定上限
4. **撑到阶段 3** — wave 间隔 1.5s、4~6 个目标，总分密度翻倍
5. **头盔兵攒 Combo 神器** — 每个 +1 连击，快速清小兵把 Combo 撑到 30
