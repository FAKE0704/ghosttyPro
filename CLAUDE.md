# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 一级原则
不进行Linux应用开发，我们是macos系统。

## 项目概述

Ghostty 是一个现代化的终端模拟器，使用 **Zig** 作为主要开发语言，支持 macOS、Linux 和 FreeBSD。项目采用跨平台架构，核心终端逻辑在 Zig 中实现，平台特定 UI 使用原生技术（macOS 用 Swift/SwiftUI + Metal，Linux 用 GTK + OpenGL）。

## 常用命令

### 构建和运行
```bash
# 构建（debug 模式是默认的）
zig build

# 构建并运行
zig build run

# 传递额外配置（在 -- 之后）
zig build run -- --config-file=/path/to/config
```

### 测试
```bash
# 运行所有 Zig 单元测试
zig build test

# 过滤特定测试
zig build test -Dtest-filter=<test name>

# 在 Valgrind 下运行（检查内存泄漏）
zig build run-valgrind
```

### libghostty-vt（独立的终端解析库）
```bash
# 构建库
zig build lib-vt

# 构建 WebAssembly 模块
zig build lib-vt -Dtarget=wasm32-freestanding

# 测试库
zig build test-lib-vt

# 测试过滤
zig build test-lib-vt -Dtest-filter=<test name>
```

### 代码格式化
```bash
# Zig 代码
zig fmt .

# 其他文件（文档、资源等）
prettier -w .

# Nix 文件格式化
alejandra .
```

### 其他命令
```bash
# 更新翻译字符串
zig build update-translations

# 构建源码包
zig build dist

# 验证源码包
zig build distcheck
```

## 代码架构

### 核心目录结构
```
src/
├── main.zig              # 主入口点
├── terminal/             # 终端核心实现
│   ├── Terminal.zig      # 终端核心逻辑
│   ├── Parser.zig        # ANSI 转义序列解析器
│   ├── Screen.zig        # 屏幕缓冲区
│   └── ...
├── renderer/             # 渲染器（OpenGL/Metal）
├── font/                 # 字体处理和字形缓存
├── os/                   # 操作系统抽象层
├── apprt/                # 应用运行时（平台特定代码）
│   ├── gtk/              # GTK 实现（Linux/FreeBSD）
│   ├── embedded/         # 嵌入式终端
│   └── ...
└── config/               # 配置系统

include/                  # C API 头文件
macos/                    # macOS 原生应用（Swift）
pkg/                      # 第三方依赖（freetype、harfbuzz 等）
po/                       # 翻译文件
test/cases/vttest/        # VT 兼容性测试套件
```

### 平台特定代码
- **macOS**: `macos/` 目录包含 Swift 代码，使用 SwiftUI 和 Metal 渲染

### 架构原则
- 共享核心逻辑用 Zig 编写，位于 `src/`
- 平台 UI 代码独立实现，通过统一的接口与核心交互
- 终端协议兼容 ANSI/VTE/xterm 标准

## macOS 开发注意事项

- **不要**使用 `xcodebuild` 构建主应用
- 使用 `zig build` 构建所有 Zig 代码和 macOS app
- 使用 `zig build run` 构建并运行 macOS 应用
- 使用 `zig build test` 运行 Xcode 测试
- 主分支开发需要 **Xcode 26 和 macOS 26 SDK**

## 代码风格

- **Zig**: 使用 `zig fmt` 格式化
- **C/C++**: Chromium 风格（见 `.clang-format`），80 字符行宽，2 空格缩进
- **Shell/Bash**: 2 空格缩进（见 `.editorconfig`）
- **Swift**: 4 空格缩进
- **Nix**: 使用 Alejandra 格式化

## 输入栈测试

如果修改输入栈（从键盘事件到 PTY 编码的部分），必须手动验证以下情况：

### Linux IME 测试矩阵
1. Wayland / X11
2. ibus / fcitx / none
3. 死键输入（如西班牙语）、CJK（如日语）、Emoji、Unicode Hex
4. ibus 版本：1.5.29、1.5.30、1.5.31

详见 `HACKING.md` 的 "Input Stack Testing" 章节。

## 调试和日志

### 查看日志
- **macOS**: `sudo log stream --level debug --predicate 'subsystem=="com.mitchellh.ghostty"'`

### 日志配置
- Debug 构建自动输出调试日志到 stderr
- 使用 `GHOSTTY_LOG` 环境变量控制日志目标：
  - `GHOSTTY_LOG=stderr` - 启用 stderr 日志
  - `GHOSTTY_LOG=macos` - 启用 macOS 统一日志
  - `GHOSTTY_LOG=true` - 启用所有日志
  - `GHOSTTY_LOG=false` - 禁用所有日志

## 相关文档

- `HACKING.md` - 详细开发指南
- `AGENTS.md` - AI 辅助开发指南
- `CONTRIBUTING.md` - 贡献指南
- `README.md` - 项目概述
