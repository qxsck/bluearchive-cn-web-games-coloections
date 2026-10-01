# 小游戏分数增加逻辑（MidAutumn2026 · 中秋活动「月饼消消乐」）

## 核心玩法简介

六边形网格（22 列 × 11 行，开局预置 2 行）中排列 4 色月饼，玩家拖动瞄准后松开，把当前月饼发射进网格；**同色 + 相邻（六向）连通数量 ≥ 3** 即触发消除。网格会随时间整体下落（「新一排生成倒数」从 15 秒开始逐步加快到 5 秒），当已有月饼触底（第 9 行）时游戏结束。另有 4 个靠消除充能的技能用于清屏。

## 核心分数公式

**本作只有两种加分事件，且全部是「固定单位分值 × 本次月饼个数」，不存在连击倍率、回合倍率或难度倍率。**

| 加分事件 | 公式 | 单位分值 |
|---|---|---|
| 同色消除 | `+10 × 本次连通个数` | **10 分/个** |
| 悬空掉落 | `+15 × 本次掉落个数` | **15 分/个** |

全部加分都经过唯一出口 `_addScore`：

```javascript
_addScore(e){ this._score+=e; this._topBar?.setScore(this._score) }
```

## 得分来源详解

### 1. 同色消除：10 分/个

```javascript
_checkElimination(e){
  const t=this._findConnected(e,!0);              // 六向同色连通
  if(t.length<3){ this._currentCombo=0; this._checkGameOver(); this._unlockShoot(); return }
  this._skillPanel?.onEliminate(e.key,t.length);  // 技能充能（见下）
  t.length>=6&&this._tokiSpecial();               // 6 连以上播放 spine 特殊动画（不加分）
  this._clearedMooncakes+=t.length;
  t.length>this._maxSingleClear&&(this._maxSingleClear=t.length);
  this._currentCombo++;
  this._currentCombo>this._maxCombo&&(this._maxCombo=this._currentCombo);
  t.forEach(n=>{n.hasball=!1,n.key=""});
  this._addScore(10*t.length);                    // ← 10 分/个
  ...
}
```

- **连通判定** `_findConnected(e, true)`：从落点出发做 BFS，只收集 `key`（颜色）相同且相邻的格子，返回整个连通块。
- **相邻方向** `_getNeighborSlots`：**六边形六向**（偶数行 `[[r,c-1],[r,c+1],[r-1,c-1],[r-1,c],[r+1,c-1],[r+1,c]]`，奇数行错位一列）。

```javascript
_getNeighborSlots(e){ const{row:t,col:i,parity:n}=e;
  return (n===0?[[t,i-1],[t,i+1],[t-1,i-1],[t-1,i],[t+1,i-1],[t+1,i]]
              :[[t,i-1],[t,i+1],[t-1,i],[t-1,i+1],[t+1,i],[t+1,i+1]])
    .map(([r,c])=>this._grid[r]?.[c]).filter(r=>!!r) }
```

### 2. 悬空掉落：15 分/个

消除后若出现与顶部断开、失去支撑的月饼，会整块掉落并**额外**计分：

```javascript
_removeFloating(e){
  const t={}, i=this._allBalls().filter(r=>r.hasball&&r.row===0);
  for(const r of i) t[`${r.row},${r.col}`]=!0;      // 从第 0 行开始向下一层层标记所有相连格
  let n=0;
  for(;n<i.length;){ const r=i[n++];
    for(const c of this._getNeighbors(r)){ const l=`${c.row},${c.col}`;
      t[l]||(t[l]=!0,i.push(c)) } }
  const o=this._allBalls().filter(r=>r.hasball&&!t[`${r.row},${r.col}`]);  // 未被标记 = 悬空
  if(!o.length){ e?.(); return }
  o.forEach(r=>{r.hasball=!1,r.key=""});
  this._droppedMooncakes+=o.length;
  this._addScore(15*o.length);                      // ← 15 分/个
  console.log("[悬空消除] "+o.length+" 个");
  ...
}
```

因为 **15 > 10**，所以「制造悬空」比单纯消除更划算，是拉高单次得分的核心手段。

### 3. 不产生分数的事件

- **发射**：`_snapToSlot` 中只做 `this._shots++`，不加分。
- **连击 `_currentCombo`**：仅用于统计（`_maxCombo` 上报），**没有任何分数倍率**——本作不存在 combo × 系数。
- **技能 1 / 技能 4 直接清除的月饼**：清除动作本身 **0 分**（见下）。

## 技能充能机制（充能不直接得分，但决定清屏效率）

技能条按「该颜色被消除的累计数量」充能，`chargePerKill1..4` 均为 **20**：

```javascript
onEliminate(s,e){                       // s = 被消除月饼的颜色 key，e = 本次连通个数
  if(e<3)return;
  const i=Number(s.match(/mooncake-(\d)/)[1]);
  const n=this._skills.find(o=>o.id===i);
  if(!n||n.ready)return;
  n.charge=Math.min(1, n.charge + e/n.threshold);      // threshold = 20
  ...
  s.label.setText(Math.round(n.charge*s.threshold)+"/"+s.threshold);   // 如 "13/20"
}
```

即：**某种颜色累计被消除 20 个** → 对应技能充能满（一次 20 连也会立刻充满）。

| 编号 | 名称 | 角色 | 效果 | 对分数的影响 |
|:---:|---|---|---|---|
| 1 | 爆裂冲击波 blast | neru（宁瑠） | 下一发命中后引爆落点周围 **5×5** 范围 | 清除本身 0 分；引爆造成的悬空按 **15/个** 结算 |
| 2 | 万能转化 wildcard | akane（茜） | 之后 **3 发**子弹变为万能色 | 更易凑出大连通 → 间接提高消除得分 |
| 3 | 精密计算 extraShots | asuna（明日奈） | 新一排生成倒数 **+15 秒**，并取消待执行的下压 | 延长存活时间 → 间接提高总分 |
| 4 | 紧急清障 clearBottom | karin（卡琳） | 清除最底部 **2 行** | 清除本身 0 分；造成的悬空按 **15/个** 结算 |

```javascript
blast:()=>{ this._activateBlast(); this._skillUseCount++; this._skillUseByCharacter.neru++ }
wildcard:()=>{ this._activateWildcard(); this._skillUseCount++; this._skillUseByCharacter.akane++ }
extraShots:()=>{ this._activateExtraShots(); this._skillUseCount++; this._skillUseByCharacter.asuna++ }
clearBottom:()=>{ this._activateClearBottom(); this._skillUseCount++; this._skillUseByCharacter.karin++ }
```

```javascript
_activateBlast(){ this._blastNextShot=!0; this._shooter.setBlastActive(!0) }
_activateWildcard(){ this._shooter.setWildcardRemaining(3) }
_activateExtraShots(){ this._pushDownPending=!1; this._previewOverlay?.addSeconds(15) }
_activateClearBottom(){                        // 清 row >= 最底行 - 1 的两行
  const e=this._allBalls().filter(n=>n.hasball&&!n.isPreview).map(n=>n.row);
  if(!e.length)return; const t=Math.max(...e);
  const i=this._allBalls().filter(n=>n.hasball&&!n.isPreview&&n.row>=t-1);
  i.forEach(n=>{ n.hasball=!1, n.key="", n.image?.setTint(4521983) });
  ...
}
_blastAround(e,t){                             // 以落点为中心 5×5
  const i=[];
  for(let o=-2;o<=2;o++) for(let r=-2;r<=2;r++){ const c=this._grid[e+o]?.[t+r]; c?.hasball&&!c.isPreview&&i.push(c) }
  i.forEach(o=>{ o.hasball=!1, o.key="", o.image?.setTint(16729088) });
  // 清除后同样走 _removeFloating —— 悬空部分按 15/个 计分
}
```

## 新一排生成倒数与难度递增

```javascript
const he=15, it=5, Gi=3e4;      // 初始 15s / 下限 5s / 加速周期 30s
_startTimer(){
  this._interval=he; this._remaining=he; this._updateText();
  this._timer=this._scene.time.addEvent({ delay:1e3, repeat:-1, callback:()=>{
    this._remaining--; this._updateText();
    this._remaining<=0 && (this._remaining=this._interval, this._onFull());   // _onFull → _pushDown() 整体下落一行
  }});
  this._decayTimer=this._scene.time.addEvent({ delay:Gi, repeat:-1, callback:()=>{
    this._interval>it && (this._interval=Math.max(it, this._interval-1));     // 每 30s 倒数 -1s，最快降到 5s
  }});
}
```

- 界面文字：`新一排生成倒数：mm:ss`
- 配置对象里的 `mooncake.pushDownInterval:30` **只是一个没有被读取的字段**，实际倒数由常量 `he = 15` 决定。
- `_activateExtraShots`（技能 3）通过 `addSeconds(15)` 直接给倒数续时，并置 `_pushDownPending=false` 取消一次待执行的下压。

## 游戏结束与最终得分

当最靠下的月饼到达 `gameOverRow = 9`（触底）即结束：

```javascript
_checkGameOver(){
  const e = 最靠下的月饼所在 row（无则 -1）;
  e > W()-3 && this._startWarningBreath(...);          // W() = gameOverRow = 9，底部警示呼吸
  e <= W()-3 && this._stopWarningBreath();
  return e===W() ? ( this._shooter?.disable(), this._tokiFail(),
    this._previewOverlay?.pause(), this._topBar?.setInteractive(!1),
    this.sound.play("fail"),
    this.time.delayedCall(1e3, async()=>{
      await y.getState().gameOver({ score:Math.floor(this._score), duration, shots,
        clearedMooncakes, droppedMooncakes, maxSingleClear, maxCombo,
        skillUseCount, skillUseByCharacter:{...}, newRows });
      y.setState({ popup:"over", gamePhase:M.Idle, score:Math.floor(this._score) });
    }), true ) : false;
}
```

- 结算页标题为「最终得分」，取 `store.score`（即 `Math.floor(this._score)`）。
- **没有本地最高分持久化**：分数只存在 zustand 内存里；每次重开（`restartGame` → `restartTick`，`_round++`）都从 0 重新计分。
- 游戏阶段枚举：`idle / countdown / playing / paused / roundTransition`。

## 上报字段与成就阈值

`gameOver` 上报的统计字段（本作离线版已被 mock，不发起真实请求）：

```
score / duration / shots / clearedMooncakes / droppedMooncakes /
maxSingleClear / maxCombo / skillUseCount / skillUseByCharacter / newRows
```

服务端任务阈值 `Pn`：

| id | 类型 | 条件 | 奖励 |
|:---:|---|---|---|
| 8 | score | **累计得分** ≥ 5000 | 青辉石 ×100 |
| 9 | score | **单次挑战得分** ≥ 3000 | 青辉石 ×100 |

> 以本作的低单位分值换算：单次 3000 分 ≈ **300 个月饼**（纯消除）或约 **200 个月饼**（全部经由悬空掉落）。

## 关键配置

```javascript
const B = {
  grid:     { cell:57, cols:22, rows:11, offsetX:0, offsetY:55 },
  goto:     { effect:1, fadeDuration:500, flashDuration:150, shakeDuration:300, shakeIntensity:.01, zoomTarget:1.5 },
  mooncake: { ballSize:64, initRows:2, gameOverRow:9,
              shootSpeed: window.IS_MOBILE?3000:3500, pushDownInterval:30 },
  skill:    { chargePerKill1:20, chargePerKill2:20, chargePerKill3:20, chargePerKill4:20 }
};
const he=15, it=5, Gi=3e4;   // 新一排倒数：初始 15s、下限 5s、加速周期 30s
```

## 高分策略总结

1. **优先制造悬空**：悬空掉落 15 分/个 > 直接消除 10 分/个，尽量把消除点选在「下方会断连」的位置。
2. **攒大连通**：一次 20 连同时满足「200 分」和「技能立即充满」，是单次收益最高的操作。
3. **技能 1 / 4 要配合悬空使用**：直接清除本身 0 分，但引爆 5×5 或清 2 行后产生的大片掉落会按 15/个 结算，等于把技能转成分数。
4. **技能 3 用来拖时间**：每用一次 +15 秒倒数，等于多出约 1~3 次新排生成，是最稳的续命手段。
5. **不要依赖连击**：`_currentCombo` 只是统计字段，不提供任何分数加成。
6. **尽早压低高列**：月饼触底（第 9 行）立即结束；在低单位分值下容错很低，宁可少连也不要堆高。