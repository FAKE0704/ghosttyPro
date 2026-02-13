# Ghostty 智能命令补全功能 - 剩余任务文档

## 项目概述

为 Ghostty 终端添加基于历史运行命令频次的智能自动补全功能。

**当前状态**: 核心数据结构和 UI 组件已完成，需要集成工作和事件处理逻辑。

---

## ✅ 已完成的工作

### Zig 核心层
| 文件 | 状态 | 说明 |
|------|------|------|
| `src/terminal/history_manager.zig` | ✅ | 按路径分组的命令历史管理器 |
| `src/terminal/completion.zig` | ✅ | 补全状态机和输入处理逻辑 |
| `src/Surface.zig` | ✅ | 添加了 completion 字段和 Completion 结构 |
| `src/terminal/main.zig` | ✅ | 导出了 HistoryManager 和 Completion |

### 配置和动作系统
| 文件 | 状态 | 说明 |
|------|------|------|
| `src/config/Config.zig` | ✅ | 添加了 6 个补全相关配置项 |
| `src/apprt/action.zig` | ✅ | 添加了 completion 和 completion_submit 动作 |
| `include/ghostty.h` | ✅ | C API 结构定义 |

### macOS UI 层
| 文件 | 状态 | 说明 |
|------|------|------|
| `macos/Sources/Features/Completion/CompletionPreviewView.swift` | ✅ | 内联灰色补全预览组件 |
| `macos/Sources/Features/Completion/CompletionMenuView.swift` | ✅ | 候选命令列表菜单 |
| `macos/Sources/Ghostty/Surface View/SurfaceView.swift` | ✅ | CompletionState ObservableObject |
| `macos/Sources/Ghostty/Surface View/SurfaceView_AppKit.swift` | ✅ | completionState 状态变量 |

---

## 🔨 剩余任务清单

### 任务 1: 实现动作处理逻辑

**文件**: `src/apprt/embedded.zig`

**说明**: 在 apprt 的动作处理函数中添加对 `completion` 和 `completion_submit` 动作的处理。

**需要添加的位置**:
```zig
// 在 embedded.zig 的 performAction 函数中，添加对以下动作的处理：
// - action.completion: 处理补全状态更新
// - action.completion_submit: 处理补全确认

// 大约在 1800 行附近，与其他动作处理逻辑一起
```

**伪代码**:
```zig
.completion => |v| {
    // v: apprt.action.Completion
    // 发送 completion 状态更新到 UI
    // 包含：prefix, preview, candidate_count, selected_index, pwd
    _ = rt_app.action(app, target, .{ .completion = v });
    return true;
},

.completion_submit => |v| {
    // v: apprt.action.CompletionSubmit
    // 用户接受了补全，将完整命令发送到 PTY
    // 然后记录到历史
    _ = rt_app.action(app, target, .{ .completion_submit = v });
    return true;
},
```

---

### 任务 2: 实现 C API 桥接

**文件**: 新建 `src/CApi.zig`（或扩展现有的 C API 文件）

**说明**: 创建 C API 函数供 macOS 层调用，用于管理补全系统。

**需要实现的函数**:
```c
// 初始化补全系统
ghostty_completion_t ghostty_completion_new(
    ghostty_surface_t surface,
    const ghostty_config_t* config
);

// 释放补全系统
void ghostty_completion_free(ghostty_completion_t completion);

// 记录命令执行
void ghostty_completion_record_command(
    ghostty_completion_t completion,
    const char* pwd,
    const char* command,
    size_t command_len
);

// 获取补全建议
size_t ghostty_completion_get_suggestions(
    ghostty_completion_t completion,
    const char* pwd,
    const char* prefix,
    size_t prefix_len,
    ghostty_completion_candidate_t* out_candidates,
    size_t max_candidates
);
```

**数据结构**:
```c
typedef struct {
    char* command;
    size_t command_len;
    size_t frequency;
} ghostty_completion_candidate_t;
```

---

### 任务 3: 集成补全初始化到 Surface

**文件**: `src/Surface.zig`

**说明**: 在 Surface 初始化时创建补全系统（如果配置已启用）。

**需要修改的位置**:
```zig
// 在 Surface.init() 函数中，大约 700 行附近
// 在搜索初始化之后添加：

// 初始化补全系统（如果配置启用）
if (config.@"completion-enabled") {
    self.completion = try alloc.create(Completion);
    try self.completion.?.init(self.alloc, config);
}
```

**还需要在 deinit 中清理**:
```zig
// 在 Surface.deinit() 中，大约 780 行
// 在搜索清理之后添加：

if (self.completion) |*c| {
    c.deinit();
    alloc.destroy(c);
    self.completion = null;
}
```

---

### 任务 4: 实现历史记录持久化

**文件**: `src/terminal/history_manager.zig`

**说明**: 添加 JSON 文件读写功能，保存命令历史到磁盘。

**需要添加的方法**:
```zig
/// 保存历史记录到文件
pub fn saveToFile(self: *const HistoryManager, path: []const u8) !void {
    const std = @import("std");
    // 创建 JSON 输出
    // 格式：{ "path1": { "cmd1": count1, "cmd2": count2 }, ... }
}

/// 从文件加载历史记录
pub fn loadFromFile(self: *HistoryManager, path: []const u8) !void {
    // 解析 JSON 并恢复历史记录
}

/// 获取默认历史文件路径
pub fn getDefaultHistoryPath(allocator: Allocator) ![]const u8 {
    // 返回 ~/.ghostty/completion_history.json
}
```

**默认文件位置**: `~/.ghostty/completion_history.json`

**JSON 格式示例**:
```json
{
  "version": 1,
  "global": {
    "git push": 45,
    "git status": 23,
    "npm test": 12
  },
  "directories": {
    "/home/user/project1": {
      "git push": 30,
      "cargo build": 15
    },
    "/home/user/project2": {
      "python main.py": 8
    }
  }
}
```

---

### 任务 5: macOS 层 C API 调用

**文件**: `macos/Sources/Ghostty/Bridge.swift` 或类似文件

**说明**: 创建 Swift 桥接代码，调用 C API 管理补全。

**Swift 代码示例**:
```swift
// GhosttyCompletionManager.swift
class GhosttyCompletionManager {
    private let completionPtr: UnsafeMutableRawPointer<OpaquePointer>

    init?(surface: OpaquePointer, config: Config) {
        completionPtr = ghostty_completion_new(surface, config.configPtr)
        guard completionPtr != nil else { return nil }
    }

    deinit {
        if completionPtr != nil {
            ghostty_completion_free(completionPtr)
        }
    }

    func recordCommand(_ command: String, in pwd: String?) {
        command.withCString { cmdPtr in
            pwd.withCString { pwdPtr in
                ghostty_completion_record_command(
                    completionPtr,
                    pwdPtr,
                    cmdPtr,
                    command.utf8.count
                )
            }
        }
    }

    func getSuggestions(for prefix: String, in pwd: String?) -> [Suggestion] {
        // 调用 ghostty_completion_get_suggestions
        // 返回候选列表
    }
}
```

---

### 任务 6: 键盘事件处理集成

**文件**: `macos/Sources/Ghostty/Surface View/SurfaceView_AppKit.swift`

**说明**: 在 keyDown 方法中添加补全模式的特殊键处理。

**需要添加的逻辑**:
```swift
override func keyDown(with event: NSEvent) {
    // ... 现有代码 ...

    // 在发送到 PTY 之前，检查补全模式
    if let completion = surfaceView.completionState {
        if handleCompletionKey(event, completion: completion) {
            return
        }
    }

    // ... 继续正常处理 ...
}

private func handleCompletionKey(
    _ event: NSEvent,
    completion: SurfaceView.CompletionState
) -> Bool {
    switch event.keyCode {
    case 48: // Tab
        if !completion.previewText.isEmpty {
            // 接受补全
            acceptCompletion(completion)
            return true
        }
        return false

    case 126: // Up Arrow
        if completion.candidates.count > 0 {
            completion.isMenuVisible = true
            completion.moveSelection(by: -1)
            return true
        }
        return false

    case 125: // Down Arrow
        if completion.candidates.count > 0 {
            completion.isMenuVisible = true
            completion.moveSelection(by: 1)
            return true
        }
        return false

    case 53: // Escape
        surfaceView.completionState = nil
        return true

    default:
        return false
    }
}
```

---

### 任务 7: 命令执行记录

**文件**: `src/apprt/embedded.zig` 或相关位置

**说明**: 在命令执行完成后记录到历史管理器。

**集成点**:
```zig
// 在 shell integration 的 command_finished 回调中
// 或在适当的位置检测到命令执行
if (self.completion) |*c| {
    // 获取当前工作目录
    const pwd = self.io.terminal.screens.active.pwd;
    // 获取执行的命令
    const command = // 从适当位置获取
    // 记录到历史
    c.history_manager.recordCommand(pwd, command) catch |err| {
        log.warn("failed to record command: {}", .{err});
    };
}
```

---

### 任务 8: 单元测试

**文件**: `src/terminal/history_manager.zig` 和 `src/terminal/completion.zig`

**说明**: 添加完整的单元测试覆盖核心功能。

**需要测试的场景**:
- [ ] HistoryManager 基本操作（添加、查询、清理）
- [ ] 按路径分组功能
- [ ] 频次统计正确性
- [ ] Completion 状态机转换
- [ ] 特殊键处理（Tab、Esc、箭头）
- [ ] 候选排序算法

---

## 📊 实现优先级

### 第一阶段：核心功能（高优先级）
1. ✅ **任务 1** - 实现动作处理逻辑
2. ✅ **任务 3** - 集成补全初始化到 Surface
3. ✅ **任务 6** - 键盘事件处理集成

完成这三项后，基本功能应该可以工作（内存模式，无持久化）。

### 第二阶段：数据持久化（中优先级）
4. ✅ **任务 4** - 实现历史记录持久化
5. ✅ **任务 2** - 实现 C API 桥接
6. ✅ **任务 7** - 命令执行记录

### 第三阶段：完善和测试（标准优先级）
7. ✅ **任务 5** - macOS 层 C API 调用
8. ✅ **任务 8** - 单元测试

---

## 🔗 调试清单

### 基本功能测试
- [ ] 在终端输入字符后显示灰色补全预览
- [ ] 按 Tab 接受补全
- [ ] 按 Esc 取消补全
- [ ] 按 上/下箭头切换候选

### 数据正确性
- [ ] 命令频次正确统计
- [ ] 按目录分组正确
- [ ] 候选排序按频次降序

### 边界情况
- [ ] 空候选列表时正确处理
- [ ] 特殊字符输入不崩溃
- [ ] 快速连续输入不卡顿

### 配置项验证
- [ ] `completion-enabled = false` 时禁用
- [ ] `completion-mode = inline` 只显示预览
- [ ] `completion-max-candidates` 限制数量

---

## 📝 注

1. **内存管理**: 所有分配都需要在适当的 deinit 函数中释放
2. **线程安全**: 历史记录可能被多个线程访问，考虑加锁
3. **错误处理**: 所有可能失败的导入都需要适当的错误处理
4. **性能**: 补全查询不应阻塞主线程，考虑异步处理

---

## 📚 参考文件

- `HACKING.md` - 项目开发指南
- `src/terminal/search.zig` - 搜索功能实现（类似结构可参考）
- `src/apprt/action.zig` - 动作系统定义

---

**创建日期**: 2026-02-13
**最后更新**: 2026-02-13
