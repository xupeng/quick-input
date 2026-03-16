# Quick Input — macOS 快速 Markdown 笔记工具设计文档

**日期**: 2026-03-16
**状态**: 已确认
**技术栈**: Swift + SwiftUI (macOS 13+)

---

## 1. 问题与目标

Notion 作为知识管理工具功能强大，但应用启动慢、操作路径深，难以满足「随手一记」的需求。Quick Input 解决这一问题：

- 全局快捷键唤起，2 秒内开始输入
- 支持 Markdown 语法高亮
- 本地先缓存，成功同步到 Notion 后自动删除
- 网络不可达时正常工作，联网后自动重试

---

## 2. 架构总览

**应用类型**: macOS Menu Bar App（无 Dock 图标，常驻菜单栏）

**权限要求**: 全局快捷键依赖 `CGEventTap`，需要用户在「系统设置 → 隐私与安全性 → 辅助功能」中授权。首次启动时需引导用户授权；若用户拒绝，降级为仅通过菜单栏图标点击唤起输入窗口。

```
┌─ App 进程（常驻）─────────────────────────────────────────┐
│                                                           │
│  MenuBarExtra (菜单栏图标)                                 │
│    ├── 显示未同步笔记数量角标                                │
│    ├── 点击 → 最近笔记列表 & 同步状态                        │
│    └── Settings → 设置页面                                 │
│                                                           │
│  GlobalHotkeyManager (需辅助功能权限)                       │
│    └── ⌘+Shift+N (可自定义) → 显示/隐藏 FloatingPanel      │
│                                                           │
│  FloatingPanel (NSPanel + SwiftUI)                        │
│    ├── MarkdownEditor (TextEditor + 语法高亮)               │
│    ├── StatusBar (同步状态指示)                             │
│    └── 快捷键: ⌘+Enter 提交, Esc 关闭                      │
│                                                           │
│  Services                                                 │
│    ├── NoteStore      — SwiftData 本地持久化               │
│    ├── NotionService  — URLSession + Notion API           │
│    ├── KeychainStore  — API Token 安全存储                 │
│    └── SettingsStore  — UserDefaults 应用配置              │
└───────────────────────────────────────────────────────────┘
```

---

## 3. 数据模型

### Note (SwiftData `@Model`)

```swift
@Model
class Note {
    var id: UUID
    var content: String        // markdown 原文
    var title: String          // 提取的标题或日期时间
    var createdAt: Date
    var syncStatus: SyncStatus // .pending | .syncing | .failed
    var notionPageId: String?  // 同步成功后记录，用于追溯
    var lastError: String?     // 失败时的错误信息
}

enum SyncStatus: String, Codable {
    case pending   // 待同步（含 App 崩溃时残留的 .syncing 记录，启动时重置）
    case syncing   // 同步中（短暂状态，仅存在于内存中）
    case failed    // 同步失败（保留本地，等待重试）
    // 注：同步成功后直接删除本地记录，不设 .synced 状态
}
```

### 标题提取规则

1. 若 markdown 第一行匹配 `^# (.+)$`，提取括号内容为标题
2. 否则使用 `yyyy-MM-dd HH:mm` 格式的时间戳

---

## 4. 同步流程

```
用户提交笔记
    │
    ├─ 生成标题（提取 H1 或使用时间戳）
    ├─ 写入 SwiftData (syncStatus = .pending)
    └─ 关闭输入窗口，显示「已保存」提示
         │
         └─ [异步] NotionService.sync(note)
                │
                ├─ syncStatus = .syncing
                │
                ├─ POST /v1/pages（见第 6.1 节完整请求体）
                │   {parent: {database_id}, properties: {title}, markdown: content}
                │
                ├── 成功 200
                │     └── 直接删除本地 Note 记录（不经过 .synced 状态）
                │
                └── 失败
                      ├── syncStatus = .failed
                      ├── lastError = 错误描述
                      └── 菜单栏图标显示失败角标
```

**重试策略**:
- App 启动时将所有残留的 `.syncing` 记录重置为 `.pending`（处理崩溃场景）
- App 启动时自动重试所有 `.pending` 和 `.failed` 笔记
- 菜单栏提供「立即重试」操作
- 429 错误：读取 `Retry-After` 头，等待后自动重试（最多 3 次）

---

## 5. UI 设计

### 5.1 浮动输入窗口 (FloatingPanel)

```
┌─────────────────────────────────────────┐
│  Quick Input                            │  ← 无标题栏或精简标题栏
├─────────────────────────────────────────┤
│                                         │
│  # 今天的想法                             │  ← TextEditor
│                                         │     • 等宽字体 (SF Mono)
│  这是一条快速笔记，**粗体** 和 `代码`     │     • Markdown 语法着色
│                                         │     • 自动换行
│  - 列表项 1                              │
│  - 列表项 2                              │
│                                         │
├─────────────────────────────────────────┤
│  ⌘+Enter 提交    Esc 关闭               │  ← 底部提示
└─────────────────────────────────────────┘
  窗口尺寸: 480×320, 居中显示, 可调整大小
```

**窗口行为**:
- 使用 `NSPanel` + `.floating` level，始终浮于其他窗口之上
- 快捷键唤起时自动聚焦，光标在文本末尾
- `Esc` 关闭但不清空内容（下次唤起恢复）
- 提交后清空内容，显示短暂成功 Toast

### 5.2 Markdown 语法高亮

使用 `NSAttributedString` + Swift Regex 实时着色：

| 语法 | 视觉效果 |
|------|---------|
| `# ## ###` 标题 | 粗体 + 大字号 |
| `**bold**` | 粗体 |
| `*italic*` | 斜体 |
| `` `code` `` | 等宽字体 + 灰色背景 |
| `[text](url)` | 蓝色 |
| `- ` 列表 | 符号变暗 |
| `> ` 引用 | 灰色 |

### 5.3 菜单栏图标

- 默认: 笔记图标（`note` SF Symbol）
- 有未同步笔记: 显示数字角标
- 有失败笔记: 橙色警告角标
- 点击展开: 最近 5 条笔记状态 + 「立即重试」按钮 + Settings 入口

### 5.4 设置页面

| 设置项 | 说明 |
|--------|------|
| Notion API Token | 从 Keychain 读写，输入框 `secureField`，配置后显示「测试连接」按钮 |
| Notion Database ID | 目标 Database 的 ID（32 位十六进制，带/不带连字符均接受），提供格式说明和「测试连接」验证 |
| 全局快捷键 | KeyRecorder 组件自定义快捷键 |
| 开机自启动 | `SMAppService.mainApp.register()` |

---

## 6. Notion API 集成

### 6.1 端点

> **注**：Notion 在 API 版本 `2025-09-03` 引入了 Enhanced Markdown 支持，`POST /v1/pages` 接受顶层 `markdown` 字段，与 `children` 互斥。最新版本 `2026-03-11` 向后兼容该功能。两个版本号均为 Notion 官方已发布版本，非虚构。参考文档：https://developers.notion.com/guides/data-apis/working-with-markdown-content

```
POST https://api.notion.com/v1/pages
Authorization: Bearer {token}
Notion-Version: 2026-03-11
Content-Type: application/json

{
  "parent": { "database_id": "{database_id}" },
  "properties": {
    "title": {
      "title": [{ "text": { "content": "{title}" } }]
    }
  },
  "markdown": "{markdown_content}"
}
```

### 6.2 错误处理

| HTTP 状态 | 处理方式 |
|-----------|---------|
| 200 成功 | 删除本地记录 |
| 429 限流 | 读 `Retry-After`，等待后重试（最多 3 次）|
| 401 未认证 | 通知用户检查 Token |
| 400 请求错误 | 标记为 failed，记录错误信息 |
| 网络不可达 | 标记为 pending，静默等待 |

### 6.3 安全

- API Token 存储在 macOS Keychain（`Security` framework）
- Database ID 存储在 `UserDefaults`（非机密）
- 不记录 API 响应内容到日志

---

## 7. 项目结构

```
quick-input/
├── QuickInput.xcodeproj/
└── QuickInput/
    ├── QuickInputApp.swift          # App 入口，MenuBarExtra
    ├── Models/
    │   └── Note.swift               # SwiftData 模型
    ├── Views/
    │   ├── FloatingPanel.swift      # NSPanel 封装
    │   ├── InputView.swift          # 主输入界面
    │   ├── MarkdownTextEditor.swift # 带语法高亮的 TextEditor
    │   ├── MenuBarView.swift        # 菜单栏下拉内容
    │   └── SettingsView.swift       # 设置页面
    ├── Services/
    │   ├── NoteStore.swift          # SwiftData 操作
    │   ├── NotionService.swift      # Notion API 调用
    │   ├── KeychainStore.swift      # Keychain 读写
    │   └── GlobalHotkeyManager.swift # 全局快捷键注册
    └── Utilities/
        └── MarkdownParser.swift     # 标题提取 + 语法高亮规则
```

---

## 8. 验证方案

1. **基本流程**: 按快捷键 → 输入 markdown → ⌘+Enter 提交 → 确认 Notion Database 出现新条目
2. **标题提取**: 以 `# 标题` 开头的笔记，Notion 页面标题应正确显示
3. **离线缓存**: 断网时提交 → 菜单栏显示待同步数 → 联网后自动同步
4. **失败重试**: 使用错误 Token → 笔记标记为 failed → 修正 Token → 点击重试 → 同步成功
5. **快捷键冲突**: 自定义快捷键后确认生效，且不与系统快捷键冲突
6. **开机自启**: 开启自启选项后，重启 Mac 确认 App 自动启动
7. **辅助功能权限授权**: 首次启动时引导授权 → 授权后全局快捷键正常触发
8. **辅助功能权限拒绝**: 拒绝授权时 → 全局快捷键不工作 → 菜单栏图标点击仍可唤起输入窗口（降级行为正常）
