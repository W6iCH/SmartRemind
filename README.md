# SmartRemind 🧠 — macOS Smart Reminder Floating Panel

[English](#english) | [中文](#chinese)

---

<a name="english"></a>
## English

**SmartRemind** is a native macOS status bar app that displays your Apple Reminders in a customizable floating window. It features AI-powered natural language input, real-time live preview, and granular visual customization.

### Features

- 🪟 **Floating Window** — Persistent borderless panel always-on-top, toggle with `⌥⇧R`
- 🧠 **AI Natural Language** — Type "Meeting tomorrow 3pm" → auto-parses to reminder with date/alarms
- 🎨 **Deep Customization** — Width, height, font size, alignment (H/V + padding), corner radius, opacity, colors
- 🏷️ **Flexible Layout** — Choose which fields appear in title row / subtitle row (flag, priority, title, list, date, location, notes, tags)
- 🎬 **Animation Modes** — 5 transition animations: fade, horizontal/vertical slide, flip, 3D rotate; or continuous smooth vertical scroll
- 🔴 **Flag Color** — Custom flag-only color for flagged items
- 📊 **Widget Overlay** — Remaining count, current time, or date badge in any corner
- ⚙️ **Draft System** — Edit settings freely, then **Apply** or **Cancel** — nothing changes until you confirm
- 🖼️ **Live Preview** — See a real-time preview of your floating window alongside settings
- 📐 **Number Input** — Every numeric setting is Slider + TextField (drag OR type)
- 📝 **Status Bar Icon** — Clean icon-only menu bar, right-click for context menu
- 📋 **Full Reminder Management** — View, edit, complete, delete, filter by list/flag
- 🤖 **Multi-Provider AI** — Add multiple LLM providers (OpenAI-compatible API), test connections

### Requirements

- macOS 14 Sonoma or later
- Apple Reminders access permission

### Installation

#### Build from Source

```bash
git clone https://github.com/W6iCH/SmartRemind.git
cd SmartRemind
swift build -c release
open .build/arm64-apple-macosx/release/SmartRemind.app
```

#### Run Debug Build

```bash
cd SmartRemind
swift build
open .build/SmartRemind.app
```

### Usage

| Action | Shortcut |
|--------|----------|
| Toggle floating window | `⌥⇧R` |
| Open main window | Right-click status bar → 主界面 |
| AI input | Type natural language in input bar, press Enter |
| Settings | Main window → 设置 tab |

### Architecture

```
SmartRemindMac/
├── App/
│   ├── AppDelegate.swift      # Status bar, menu panel, hotkey, app lifecycle
│   └── FloatingPanel.swift    # NSPanel subclass — borderless always-on-top window
├── Models/
│   ├── AppearanceConfig.swift  # @AppStorage-backed config + SettingsDraft
│   ├── ReminderItem.swift      # Reminder data model
│   └── LLMConfig.swift         # LLM provider configuration
├── Views/
│   ├── FloatingWindowView.swift  # Floating panel SwiftUI content
│   ├── MainWindowView.swift      # Main window: reminders list + settings panel + live preview
│   ├── MenuBarPopoverView.swift  # Status bar popover
│   ├── PopoverInputArea.swift   # Input bar (IME-safe NSTextField wrapper)
│   ├── EditReminderSheet.swift  # New/Edit reminder sheets
│   └── SettingsView.swift       # (replaced by integrated settings in MainWindowView)
├── Services/
│   ├── ReminderManager.swift    # EventKit wrapper (CRUD + fetch)
│   ├── LLMService.swift         # OpenAI-compatible API client
│   └── SmartReminderCoordinator.swift  # NLP → parse → geocode → save pipeline
└── SmartRemindMacApp.swift      # @main entry point
```

### Tech Stack

- **Language:** Swift 5.9+
- **UI:** SwiftUI + AppKit (NSPanel, NSTextField)
- **Persistence:** `@AppStorage` (UserDefaults)
- **Reminders:** EventKit
- **AI:** OpenAI-compatible chat completions API
- **Build:** Swift Package Manager (`swift build`)

### Credits

- **Built with [OpenClaw](https://github.com/openclaw/openclaw)** — Desktop AI assistant platform
- **AI Model: [DeepSeek V4 Pro](https://deepseek.com)** — Code generation, architecture design, and iterative refinement
- **Icons:** SF Symbols (Apple)

### License

MIT © 2026 Caihou Wang (which)

---

<a name="chinese"></a>
## 中文

**SmartRemind** 是一款原生 macOS 状态栏应用，可将 Apple 提醒事项以可定制的悬浮窗形式常驻桌面。支持 AI 自然语言输入、实时预览和精细外观调节。

### 功能特性

- 🪟 **悬浮窗** — 无边框始终置顶面板，`⌥⇧R` 切换显示/隐藏，Esc 不关闭
- 🧠 **AI 自然语言** — 输入「明天下午3点开会」→ 自动解析出标题、截止日期、闹钟并写入系统提醒
- 🎨 **深度自定义** — 宽度、高度、字号、水平/垂直对齐 + 缩进偏移、圆角、透明度、颜色
- 🏷️ **灵活布局** — 自由选择标题行/副标题行显示哪些字段（旗标、优先级、标题、列表、日期、位置、备注、标签）
- 🎬 **动画模式** — 5 种切换动画（淡入淡出、水平滑动、垂直滑动、翻转、3D 旋转）+ 连续匀速垂直滚动
- 🔴 **旗标颜色** — 旗标项目专用颜色，标题和 flag 图标均可配置
- 📊 **插件叠加** — 角落显示剩余待办数、当前时间或日期徽标
- ⚙️ **草稿系统** — 随意修改设置，点「应用」(⌘S) 才生效，点「取消」全部撤销
- 🖼️ **实时预览** — 设置面板右侧实时显示悬浮窗预览，所见即所得
- 📐 **数字双输入** — 每个数值设置均可滑动拖拽或直接键入
- 📝 **状态栏图标** — 纯图标菜单栏，右键唤出上下文菜单
- 📋 **完整提醒管理** — 查看、编辑、完成、删除，按列表/旗标筛选
- 🤖 **多供应商 AI** — 添加多个 LLM 供应商（OpenAI 兼容 API），测试连接

### 系统要求

- macOS 14 Sonoma 及以上
- Apple 提醒事项访问权限

### 安装

#### 从源码构建

```bash
git clone https://github.com/W6iCH/SmartRemind.git
cd SmartRemind
swift build -c release
open .build/arm64-apple-macosx/release/SmartRemind.app
```

#### 调试运行

```bash
cd SmartRemind
swift build
open .build/SmartRemind.app
```

### 使用方式

| 操作 | 快捷键 |
|------|--------|
| 切换悬浮窗 | `⌥⇧R` |
| 打开主界面 | 右键状态栏图标 → 主界面 |
| AI 输入 | 在输入框输入自然语言，回车 |
| 设置 | 主界面 → 设置标签页 |

### 技术栈

- **语言:** Swift 5.9+
- **UI 框架:** SwiftUI + AppKit（NSPanel、NSTextField）
- **持久化:** `@AppStorage`（UserDefaults）
- **提醒事项:** EventKit
- **AI:** OpenAI 兼容的 Chat Completions API
- **构建:** Swift Package Manager（`swift build`）

### 致谢

- **由 [OpenClaw](https://github.com/openclaw/openclaw) 驱动开发** — 桌面 AI 助手平台，负责项目管理、代码编排和多轮迭代
- **AI 模型: [DeepSeek V4 Pro](https://deepseek.com)** — 代码生成、架构设计和迭代优化
- **图标:** SF Symbols（Apple）

### 许可证

MIT © 2026 Caihou Wang (which)
