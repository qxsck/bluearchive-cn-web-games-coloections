# 小游戏分数增加逻辑

## 核心分数公式

游戏的核心分数每秒更新一次：
**分数公式：每秒得分 = 加速倍率 × 回合倍率 × 难度倍率 × 火车长度**

```javascript
// 分数累加器每帧增加时间增量 n（毫秒）
this._scoreAcc += n;
// 累计达到 1000ms（1秒）时触发一次分数结算
if (this._scoreAcc >= 1e3) {
  this._scoreAcc -= 1e3;
  const c = this._isAccelerating ? 1.5 : 1;        // 加速倍率
  const l = 1 + (this._round - 1) * .1;             // 回合倍率
  const u = this._difficulty === "hard" ? I.difficulty.scoreMultHard : 1; // 难度倍率
  const h = c * l * u * this.snakeObj.cells.length; // 最终得分
  this._score += h;
  this.topBar.setScore(Math.floor(this._score));
}
```

## 各倍率详解

| 倍率 | 变量 | 取值 | 说明 |
|------|------|------|------|
| 加速倍率 | `c` | 1.0 / 1.5 | 按住空格/加速按钮时为 1.5，否则 1.0 |
| 回合倍率 | `l` | 1.0, 1.1, 1.2... | `1 + (回合数-1)×0.1`，第1回合1.0，第2回合1.1，每回合递增10% |
| 难度倍率 | `u` | 1.0 / 1.2 | 困难模式 `scoreMultHard=1.2`，普通模式 1.0 |
| 火车长度 | `cells.length` | 动态 | 火车车厢数量，吃车厢道具或生长时会增加 |

## 分数结算机制

- **结算频率**：每 1000ms（1秒）结算一次
- **结算条件**：仅在 `scoreboardActive`（计分板激活，即游戏进行中）时累加
- **初始分数**：0（或上一回合保留的 `preservedScore`）

## 火车长度增加方式

1. **自然生长**：每 `GROW_INTERVAL`（15秒）自动生长一节车厢

   ```javascript
   this._growAcc += n;
   if (this._growAcc >= this.GROW_INTERVAL * 1e3) {
     this._growAcc -= this.GROW_INTERVAL * 1e3;
     this.snakeObj.grow();  // cells.push({...})
   }
   ```

2. **车厢道具（CAR_BOX）**：拾取后立即生长一节车厢并恢复30能量

   ```javascript
   case N.CAR_BOX:
     this.energy = n(this.energy + 30, 0, 100);
     this.snakeObj.grow();  // 增加长度→间接增加每秒得分
     break;
   ```

3. **胜利回合**：通关后火车额外生长一节，并保留分数进入下一回合

   ```javascript
   _winRound() {
     this.snakeObj.grow();
     // ... 保留状态重启
     preservedScore: this._score,
     preservedRound: this._round + 1,
   }
   ```

## 道具系统（不直接加分，但间接影响分数）

道具拾取通过 `_applyPowerUp` 应用效果，**不直接增加分数**，而是通过改变火车长度或延长生存时间间接提升得分：

| 道具 | 权重 | 效果 | 对分数的影响 |
|------|------|------|-------------|
| ENERGY_STATION 能量站 | 25% | +30能量，10秒不耗能 | 延长生存时间 |
| MAGNET 磁铁 | 25% | +20能量，5秒自动吸取道具 | 更易获取其他道具 |
| TIME_BUFFER 时间缓冲 | 15% | +20能量，10秒速度×2 | 移动更快，`_isAccelerating`状态 |
| CAR_BOX 车厢 | 15% | +30能量，立即生长一节 | **直接增加 `cells.length`** |
| BULLDOZER 推土机 | 10% | +20能量，10秒可撞障碍 | 避免碰撞死亡 |

## 游戏结束分数

游戏结束时（碰撞死亡），最终分数取整后存入状态：

```javascript
O.setState({popup:"over", gamePhase:le.Idle, score:Math.floor(this._score)})
```

## 关键配置（配置对象 `I`）

```javascript
{
  difficulty: { obstacleMultHard: 1.5, scoreMultHard: 1.2 },
  energy: { drainNormal: 2, drainFast: 2.5, growInterval: 15, moveIntervalNormal: 400, moveIntervalFast: 200 },
  powerUp: { maxOnMap: 4, spawnInterval: 4e3, durationMagnet: 5e3, ... },
  winRound: { amount: 35, outDuration: 800, inDuration: 800 }
}
```

## 总结

**分数增长的核心策略**：

1. **保持加速**（×1.5倍率）- 按住空格键
2. **收集车厢道具** - 增加 `cells.length` 直接提升每秒基础分
3. **存活到高回合** - 回合倍率每回合+10%
4. **选择困难模式** - 额外×1.2倍率（但障碍物也×1.5）
5. **利用能量站/推土机** - 延长生存时间以累积更多分数
