# Ghostty Pro

> 个人基于 [Ghostty](https://github.com/ghostty-org/ghostty) 的 Fork 项目，添加了实用功能增强

## 简介

Ghostty Pro 是一个现代化的终端模拟器， fork 自优秀的开源项目 [Ghostty](https://github.com/ghostty-org/ghostty)。在此基础上，我添加了一些实用的功能增强，打造更顺手的终端体验。

> **注意**：本项目主要供个人使用和实验，欢迎感兴趣的伙伴参考使用。

## 新增功能

### 1. GUI 设置界面 🎨

无需手动编辑配置文件，通过图形界面轻松配置终端：
- 字体、颜色、主题设置
- 快捷键绑定
- 窗口和行为选项
- 实时预览配置效果

### 2. 智能命令补全 ⚡

类似 IDE 的智能补全体验：
- **内联预览**：灰色显示建议补全内容，按 Tab 接受
- **命令历史**：自动学习你的使用习惯，优先显示常用命令
- **上下文感知**：根据当前目录提供相关建议
- **菜单选择**：使用上下键浏览候选项

## 快速开始

### 构建和运行

```bash
# 构建
zig build

# 运行
zig build run
```

### 使用命令补全

1. 输入命令前缀（如 `git` 或 `cd`）
2. 灰色文本会显示建议补全
3. 按 **Tab** 接受补全，或按 **↑/↓** 浏览其他选项
4. 按 **Esc** 取消补全

## 原项目文档

Ghostty 原项目的完整文档可作为参考：
- [关于 Ghostty](https://ghostty.org/docs/about)
- [配置文档](https://ghostty.org/docs)
- [贡献指南](CONTRIBUTING.md)
- [开发文档](HACKING.md)

## 开发计划

- [x] GUI 设置界面
- [x] 智能命令补全
- [ ] 更多实用功能（待规划...）

## 许可证

本项目继承原项目的 [MIT 许可证](LICENSE)。

---

**原项目**: [ghostty-org/ghostty](https://github.com/ghostty-org/ghostty)
