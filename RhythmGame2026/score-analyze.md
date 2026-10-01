# 小游戏分数增加逻辑（RhythmGame2026 · 蔚蓝档案节拍游戏）

## 核心玩法简介

这是一个**多轨节拍游戏**，节拍音符（Note）在 4~8 条轨道上从上方落下，玩家按键或点击底部按钮在判定线处击中，获得对应判定等级的分数。有普通（Tap）、长按（Hold / Slide）等类型音符，支持「狂热模式（Crazy Mode）」提供 2 倍分数。

## 音符判定等级与基础得分

### 1. Tap 音符（单点）/ Hold 头 / Hold 尾

| 判定等级 | 英文常量 | 判定范围（相对按钮半径） | 基础分 | 音效 |
|:------:|:--------:|:----------------------:|:----:|:----:|
| 超完美 VIOLENT | S.VIOLENT | 距离 <= 0.75 * buttonRadius | **150** | "double"（双击音） |
| 完美 EXACT | S.EXACT | 0.75r < 距离 <= 1.5r | **100** | "single"（单击音） |
| 失误 MISS | S.MISS | 距离 > 1.5r 或超时未击中 | 0 | "click" |

```javascript
// 判定距离公式与得分映射
h <= this.perfectRange      // 0.75 * buttonRadius
  ? (result = VIOLENT, score = 150, sfx = "double")
  : (result = EXACT,   score = 100, sfx = "single");
h > this.exactRange
  ? (result = MISS,    score = 0);
```

### 2. Hold 长按音符的尾部判定（已修复）

#### 修复前的问题
- 长条收缩完成时（`updateShrink` 中 `s >= 1`），无论玩家是否仍在按住，尾部都会被判定为 **MISS**
- 自动命中回调（`onTailAutoHitCallback`）硬编码 100 分 EXACT，未考虑头部判定结果

#### 修复后的逻辑

**(a) 长按到底自动命中（autoHitTail）**

当长条收缩完成（`s >= 1`）时，若玩家仍按住（`isPressing = true`）且头部已命中（`isHeadHit = true`），则自动触发尾部 **EXACT** 判定：

```javascript
// updateShrink 中 shrink 完成时：
s >= 1 && (
  !this.isAutoMode &&
  this.isHeadHit &&
  !this.isTailHit &&
  this.isPressing &&    // ← 玩家仍在按住
  this.autoHitTail(),   // ← 触发自动 EXACT 命中
  this.isShrinking = !1,
  // 若玩家已松手(hasTailUserInteraction)则触发 MISS
  !this.isAutoMode &&
  this.isHeadHit &&
  !this.isTailHit &&
  this.hasTailUserInteraction &&
  this.triggerTailMiss(),
  this.fadeOutAndDestroy()
)
```

```javascript
autoHitTail = function() {
  // 前置条件: 头部已命中 && 尾部未命中 && 未整体 MISS
  if (!this.isHeadHit || this.isTailHit || this.isMissed) return;
  this.isTailHit = true;
  this.isPressing = false;
  this.tailJudgeResult = r.EXACT;   // 自动 EXACT 判定
  this.useVirtualTailJudge = false;
  this.pauseRotation();
  this.onTailHitCallback && this.onTailHitCallback(this, r.EXACT);
  this.onTailAutoHitCallback && this.onTailAutoHitCallback(this, r.EXACT);
  this.isShrinking || this.fadeOutAndDestroy();
}
```

**(b) 手动松手尾部判定（tryHitTail）**

玩家在尾部到达判定线附近松手时，通过距离计算尾部判定：

```javascript
tryHitTail = function(buttonY) {
  // 使用虚拟尾部判定坐标
  var tailY = this.getTailWorldY();
  var dist = Math.abs(tailY - buttonY);
  if (dist > this.exactRange)      // 0.75r 内
    return { result: VIOLENT, score: 150, sfx: "double" };
  else if (dist > this.missRange)  // 1.5r 内
    return { result: EXACT, score: 100, sfx: "single" };
  else
    return { result: MISS, score: 0, sfx: "click" };
}
```

### 3. Hold 音符最终得分计算（calculateFinalResult）

头和尾的判定结果取**平均值**作为 Body（长条整体）的最终得分：

```javascript
calculateFinalResult = function() {
  if (!this.headJudgeResult || !this.tailJudgeResult)
    return { result: MISS, score: 0 };

  // 得分字典
  var dict = {};
  dict[VIOLENT] = 150;
  dict[EXACT]   = 100;
  dict[MISS]    = 0;

  // 头部 + 尾部 取平均
  var avg = (dict[this.headJudgeResult] + dict[this.tailJudgeResult]) / 2;
  return {
    result: avg >= 125 ? VIOLENT : avg >= 50 ? EXACT : MISS,
    score:  Math.floor(avg)
  };
}
```

### 4. 头部 MISS 强制 0 分规则

所有尾部计分路径（自动命中 / 手动松手 / 键盘操作）均已增加**头部 MISS 检查**：

```javascript
// HitButton 中三处统一检查：
// onTailAutoHitCallback / onTouchEnd / keyboard handler
if (headJudgeResult === MISS) {
  // 强制 MISS: 0 分 + 断连 Combo
  this.showHitEffect(MISS);
  this.onNoteMissCallback(laneIndex, false);
} else {
  // 正常: 使用 calculateFinalResult 计算平均值
  var fr = calculateFinalResult();
  this.showHitEffect(fr.result);
  this.onNoteHitCallback(laneIndex, fr.result, fr.score, true);
}
```

### 5. 完整计分规则表

| 头部判定 | 尾部判定 | 平均分 | 最终结果 | 得分 | 说明 |
|:-------:|:-------:|:-----:|:-------:|:---:|:----:|
| VIOLENT (150) | VIOLENT (150) | 150 | **VIOLENT** | **150** | 头尾双暴击 |
| VIOLENT (150) | EXACT (100) | 125 | **VIOLENT** | **125** | 头暴击+尾命中 |
| EXACT (100) | VIOLENT (150) | 125 | **VIOLENT** | **125** | 头命中+尾暴击 |
| VIOLENT (150) | MISS (0) | 75 | **EXACT** | **75** | 头暴击+尾MISS |
| EXACT (100) | EXACT (100) | 100 | **EXACT** | **100** | 头尾双命中 |
| EXACT (100) | MISS (0) | 50 | **EXACT** | **50** | 头命中+尾MISS |
| **MISS (0)** | **任意** | — | **MISS** | **0** | **强制 0 分+断连** |

### 6. 各类型得分汇总

| 音符类型 | 头判得分 | 尾判得分 | Body 平均得分 | 总得分示例（全 VIOLENT） |
|---------|:------:|:------:|:----------:|:--------------------:|
| Tap 单点 | 150 / 100 / 0 | — | — | 150（完美一击） |
| Hold 长按 | 150 / 100 / 0 | 150 / 100 / 0 | (头+尾)/2 | 150+150 = 300 |
| Slide 长条 | 同源实现 | 同源实现 | 同源实现 | 与 Hold 等价 |

## 总分累加器与狂热模式 2x 倍率

### onNoteHit 分数累加

每次 onNoteHit（头命中/尾命中/Body 结算都会触发）：

```javascript
u.onNoteHit = function(lane, result, score, isHoldBodyHit) {
  if (void 0 === isHoldBodyHit && (isHoldBodyHit = !1),
      result !== S.MISS) {
    var r = score;
    // 狂热模式 2x 得分
    this.isCrazyMode() && (r = 2 * score);
    this.currentScore += r;
    this.updateScoreUI();

    // 狂热槽累积（非 Crazy 时命中才加）
    this.crazyManager && this.crazyManager.addCrazyValue(result, this.remainingTime);

    // Support 角色响应（如果启用）
    this.supportManager && (isHoldBodyHit || this.supportManager.onTapNoteHit(result));

    // Combo 累加（score>0 时才算 Combo）
    score > 0 && (
      this.currentCombo++,
      this.currentCombo > this.maxCombo && (this.maxCombo = this.currentCombo),
      this.currentCombo >= 2 && this.showComboCount(this.currentCombo)
    );
  } else {
    // MISS -> 断连
    this.onNoteMiss(lane, !0);
  }
};
```

### 狂热模式（Crazy Mode）总结

| 项目 | 数值 | 说明 |
|-----|:---:|------|
| 狂热槽上限 MAX_CRAZY_VALUE | 100 | 满槽进入 Crazy Mode |
| VIOLENT 狂热槽 +2 / EXACT 狂热槽 +1 | - | 只有非 Crazy 时命中才加 |
| Crazy Mode 持续 CRAZY_MODE_DURATION | 10 秒 | 进入后倒计时 |
| Crazy Mode 分数倍率 | **2x** | `r = 2 * score` |
| Crazy Time <= 10 秒时 | 可手动退出 | 倒计时最后 10 秒允许提早结束 |

```javascript
// addCrazyValue 实现
l.addCrazyValue = function (judge, remainTime) {
  this.isCrazyMode || (
    judge === VIOLENT ? this.crazyValue += 2
                      : (judge === EXACT && (this.crazyValue += 1)),
    this.crazyValue > this.MAX_CRAZY_VALUE && (this.crazyValue = this.MAX_CRAZY_VALUE)
  );
};

// 进入 Crazy Mode（分数 2x、背景/角色视觉切换）
l.enterCrazyMode = function (remainTime) {
  this.isCrazyMode || (
    this.isCrazyMode = !0,
    this.crazyModeTime = (remainTime < this.CRAZY_MODE_DURATION)
                           ? remainTime
                           : this.CRAZY_MODE_DURATION,
    this.applyCrazyModeVisuals(),
    this.onCrazyModeStartCallback && this.onCrazyModeStartCallback()
  );
};

// 每帧更新 Crazy（倒计时、满 100 自动退出）
l.updateCrazy = function (dt, remainTime, autoExit) {
  if (this.isCrazyMode && !this.isPaused) {
    this.crazyModeTime -= dt;
    // 剩余 <= 10 秒时允许提早结束
    !autoExit && remainTime <= 10 && autoExit && autoExit();
    // 倒计时结束自动退出
    // ...
  }
};
```

## Combo 连击与断连

| 事件 | Combo 变化 |
|------|:----------:|
| 任意得分 > 0 的命中 | **+1**（同时更新 maxCombo） |
| 任意 MISS（玩家没打到或判定失准） | **归零**（currentCombo = 0） |
| onNoteMiss 回调（由 NoteSpawner 自动检测到达判定线超时） | **归零** |

Combo 视觉显示阈值：Combo >= 2 才弹出 Combo 计数特效 `showComboCount()`。

```javascript
// MISS 回调
u.onNoteMiss = function (t, e) {
  this.currentCombo > 0 && (this.currentCombo = 0);     // 断连
  this.supportManager && this.supportManager.onNoteMiss();
};
```

## 最终得分结构与提交

游戏结束时把 `{score, combo}`（最终分数与最大 Combo）传回 API：

```javascript
// in generator next 6
case 6:
  o = { score: t, combo: r };  // t = currentScore 最终得分，r = maxCombo 最大连击
  return e.next = 9, l(s, o, a);  // sendScore API
```

最终排名（rank）通常由得分映射到等级（C/B/A/S/SS/SSS），具体映射在服务端或关卡配置中。

## 高分策略总结

1. **保证全连（Full Combo）** — 一断连就断 Combo，且 Crazy 槽增长速度大幅下降
2. **追求 VIOLENT 判定** — 每个 VIOLENT 比 EXACT 多 50 分 + Crazy 槽 +2 比 +1 快一倍进 Crazy
3. **尽快进 Crazy Mode** — Crazy 期间 2x 得分，如果前半曲能进 2 次 Crazy，总分离谱高
4. **Hold 音符头尾都要按到** — Body 得分是头+尾平均，尾判 MISS 直接让 Body 分砍半
5. **Crazy 模式内不 MISS** — MISS 会断连（虽然 Crazy 时还是 2x，但断连影响视觉反馈）
6. **优先精准而不是速度** — EXACT 100 分 vs MISS 0 分的差距（100 分 * 2x Crazy = 200 分差）远比判定偏差大