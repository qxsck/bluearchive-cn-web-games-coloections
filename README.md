# 蔚蓝档案 网页小游戏合集（Blue Archive Web Games）

> 个人学习与技术研究项目 · 非商业 · 同人性质
> 相关素材版权归 **Yostar, Inc.** 及原权利人所有，详见 [DISCLAIMER.md](./DISCLAIMER.md)

---

# 中文

## 项目简介

本项目是《蔚蓝档案》（Blue Archive）网页活动小游戏的**本地网页化整理与再实现**。相关网页活动结束后便无法再游玩，本项目将合集内各款作品整理为可离线运行的纯前端网页，并提供一个零依赖的本地 HTTP 服务器，让玩家可以随时再次体验。

| 游戏 | 类型 | 副标题 |
| --- | --- | --- |
| RailOps2026 | 类贪吃蛇 | 全速前进！铁轨巡游大作战 |
| RhythmGame2026 | 音乐节奏 | 炫音节拍 |
| Anniversary2025 | 打地鼠 | 宴会上也要维护风纪！~日奈的热身运动~ |
| MidAutumn2026 | 类祖玛 | 月饼复制危机！泡泡月饼大作战 |

## 快速开始

### 环境要求

- 已安装 [Node.js](https://nodejs.org/)（任意较新版本即可，无需安装任何第三方依赖）

### 运行方式

**方式一：双击脚本（Windows）**

直接双击根目录下的 `start.bat`，脚本会自动执行 `node server.js`。

**方式二：命令行**

```bash
node server.js
```

启动后访问合集入口页：<http://localhost:3000/>

各作品直达地址：

| 游戏 | 地址 |
| --- | --- |
| RailOps2026 | http://localhost:3000/RailOps2026/ |
| RhythmGame2026 | http://localhost:3000/RhythmGame2026/ |
| Anniversary2025 | http://localhost:3000/Anniversary2025/ |
| MidAutumn2026 | http://localhost:3000/MidAutumn2026/ |

停止服务：双击 `stop.bat`，或在控制台按 `Ctrl + C`。

## 目录结构

```
.
├── index.html            # 合集入口页（选择游戏）
├── server.js             # 本地静态资源服务器（端口 3000）
├── start.bat             # 一键启动（Windows）
├── stop.bat              # 一键停止（Windows）
├── RailOps2026/          # 作品：类贪吃蛇
├── RhythmGame2026/       # 作品：音乐节奏
├── Anniversary2025/      # 作品：打地鼠
├── MidAutumn2026/        # 作品：类祖玛
├── DISCLAIMER.md         # 免责声明（中英双语）
└── README.md             # 本文件
```

## 技术栈

- **运行形态**：纯前端网页，本地静态服务器托管
- **渲染 / 游戏框架**：Phaser、PIXI、Spine
- **应用层**：React
- **服务器**：Node.js 原生 `http` 模块，零第三方依赖

## 关于本项目的制作说明

**本项目主要由 AI 辅助生成与迭代完成。**

- 从资源下载整理、代码分析适配到文档撰写，绝大部分内容由 AI 协助产出；
- 使用的模型**包括但不限于 DeepSeek**；
- 人工主要负责需求提出、效果验收与调优打磨。

因此，代码与文档中可能存在 AI 生成内容常见的疏漏或风格特征，欢迎指出与改进。

## 免责声明

本项目仅用于个人学习、技术研究与交流，**严禁任何商业用途**。
如原权利人认为本项目侵犯其合法权益，请联系维护者，将立即删除相关内容。

完整条款请阅读 [DISCLAIMER.md](./DISCLAIMER.md)。

---

# English

## Overview

This project is a **local web port / re-implementation** of the web event mini games of *Blue Archive*. Once a web event ends, its mini game becomes unplayable; this project packages every title in the collection as an offline-capable, pure front-end web page and serves them with a dependency-free local HTTP server, so players can experience them again at any time.

| Game | Genre | Subtitle |
| --- | --- | --- |
| RailOps2026 | Like Snake | 全速前进！铁轨巡游大作战 |
| RhythmGame2026 | Rhythm | 炫音节拍 |
| Anniversary2025 | Whac‑A‑Mole | 宴会上也要维护风纪！~日奈的热身运动~ |
| MidAutumn2026 | Like zuma | 月饼复制危机！泡泡月饼大作战 |

## Getting Started

### Requirements

- [Node.js](https://nodejs.org/) installed (any reasonably recent version; no third-party dependencies required)

### How to Run

**Option 1: Double-click the script (Windows)**

Double-click `start.bat` in the project root; it runs `node server.js` automatically.

**Option 2: Command line**

```bash
node server.js
```

Then open the collection launcher: <http://localhost:3000/>

Direct links to each title:

| Game | URL |
| --- | --- |
| RailOps2026 | http://localhost:3000/RailOps2026/ |
| RhythmGame2026 | http://localhost:3000/RhythmGame2026/ |
| Anniversary2025 | http://localhost:3000/Anniversary2025/ |
| MidAutumn2026 | http://localhost:3000/MidAutumn2026/ |

To stop: double-click `stop.bat`, or press `Ctrl + C` in the console.

## Directory Structure

```
.
├── index.html            # Collection launcher (game picker)
├── server.js             # Local static file server (port 3000)
├── start.bat             # One-click start (Windows)
├── stop.bat              # One-click stop  (Windows)
├── RailOps2026/          # Title: Like Snake
├── RhythmGame2026/       # Title: Whac‑A‑Mole
├── MidAutumn2026/        # Title: Like zuma
├── DISCLAIMER.md         # Disclaimer (bilingual)
└── README.md             # This file
```

## Tech Stack

- **Runtime form**: Pure front-end web, hosted by a local static server
- **Rendering / game frameworks**: Phaser, PIXI, Spine
- **Application layer**: React
- **Server**: Node.js native `http` module, zero third-party dependencies

## How This Project Was Made

**This project was mainly produced and iterated with the help of AI.**

- From asset downloading and organization, code analysis and adaptation, to documentation, the vast majority of the work was produced with AI assistance;
- The models used **include but are not limited to DeepSeek**;
- Human effort focused on requirements, acceptance testing, and fine-tuning.

As a result, the code and docs may carry the kind of oversights or stylistic traits typical of AI-generated content. Feedback and improvements are welcome.

## Disclaimer

This project is for personal learning, technical research, and exchange only. **Any commercial use is strictly prohibited.**
If the original rights holder believes this project infringes its legitimate rights and interests, please contact the maintainer, and the relevant content will be removed immediately upon notification.

For the full terms, please read [DISCLAIMER.md](./DISCLAIMER.md).