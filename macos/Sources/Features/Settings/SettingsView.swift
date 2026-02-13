import SwiftUI

// MARK: - Configuration Categories

enum SettingsCategory: String, CaseIterable, Identifiable {
    case appearance
    case font
    case colors
    case terminal
    case window
    case keybindings
    case advanced

    var displayName: String {
        switch self {
        case .appearance: "外观"
        case .font: "字体"
        case .colors: "颜色"
        case .terminal: "终端"
        case .window: "窗口"
        case .keybindings: "键盘绑定"
        case .advanced: "高级"
        }
    }

    var iconName: String {
        switch self {
        case .appearance: "paintbrush"
        case .font: "textformat"
        case .colors: "palette"
        case .terminal: "terminal"
        case .window: "macwindow"
        case .keybindings: "command"
        case .advanced: "gearshape"
        }
    }

    var id: String { self.rawValue }
}

// MARK: - Category Views

struct AppearanceCategoryView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Text("外观")
                    .font(.headline)

                Text("配置终端窗口的外观设置")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Image(systemName: "paintbrush")
            }

            Section {
                HStack {
                    Text("窗口透明度")
                    Spacer()
                    Text("\(Int(viewModel.windowOpacity * 100))%")
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: $viewModel.windowOpacity,
                    in: 0...1,
                    step: 0.01
                )
            } header: {
                Text("窗口透明度")
            }

            Section {
                Picker("主题", selection: $viewModel.themeIndex) {
                    ForEach(0..<SettingsViewModel.themeOptions.count, id: \.self) { index in
                        Text(SettingsViewModel.themeOptions[index].displayName)
                            .tag(index)
                    }
                }
            } header: {
                Text("主题")
            }

            Section {
                Toggle("背景模糊", isOn: $viewModel.backgroundBlurEnabled)
            } header: {
                Text("背景模糊")
            }
        }
        .formStyle(.grouped)
    }
}

struct FontCategoryView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Text("字体")
                    .font(.headline)

                Text("配置终端显示的字体设置")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Image(systemName: "textformat")
            }

            Section {
                Picker("字体系列", selection: $viewModel.fontFamilyIndex) {
                    ForEach(0..<SettingsViewModel.fontFamilyOptions.count, id: \.self) { index in
                        Text(SettingsViewModel.fontFamilyOptions[index])
                            .tag(index)
                    }
                }
            } header: {
                Text("字体系列")
            }

            Section {
                HStack {
                    Text("字体大小")
                    Spacer()
                    Text("\(Int(viewModel.fontSize))pt")
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: $viewModel.fontSize,
                    in: 8...72,
                    step: 1
                )
            } header: {
                Text("字体大小")
            }

            Section {
                HStack {
                    Text("行间距")
                    Spacer()
                    Text("\(viewModel.lineSpacing, specifier: "%.1f")")
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: $viewModel.lineSpacing,
                    in: 0...10,
                    step: 0.1
                )
            } header: {
                Text("行间距")
            }
        }
        .formStyle(.grouped)
    }
}

struct ColorsCategoryView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Text("颜色")
                    .font(.headline)

                Text("配置终端文本和背景颜色")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Image(systemName: "palette")
            }

            Section {
                HStack {
                    Text("前景色")
                    Spacer()
                    ColorPicker("前景色", selection: $viewModel.foregroundColor)
                }

                HStack {
                    Text("背景色")
                    Spacer()
                    ColorPicker("背景色", selection: $viewModel.backgroundColor)
                }
            } header: {
                Text("基础颜色")
            }

            Section {
                HStack {
                    Text("光标颜色")
                    Spacer()
                    ColorPicker("光标颜色", selection: $viewModel.cursorColor)
                }
            } header: {
                Text("光标")
            }

            Section {
                Toggle("使用自定义调色板", isOn: $viewModel.useCustomPalette)
            } header: {
                Text("调色板")
            }
        }
        .formStyle(.grouped)
    }
}

struct TerminalCategoryView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Text("终端")
                    .font(.headline)

                Text("配置终端行为设置")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Image(systemName: "terminal")
            }

            Section {
                Picker("光标样式", selection: $viewModel.cursorStyleIndex) {
                    Text("块").tag(0)
                    Text("下划线").tag(1)
                    Text("竖线").tag(2)
                }
                .pickerStyle(.menu)
            } header: {
                Text("光标样式")
            }

            Section {
                HStack {
                    Text("滚动距离")
                    Spacer()
                    Text("\(viewModel.scrollbackLines) 行")
                        .foregroundColor(.secondary)
                }

                Stepper(
                    value: $viewModel.scrollbackLines,
                    in: 0...100000,
                    step: 100
                )
            } header: {
                Text("滚动历史")
            }
        }
        .formStyle(.grouped)
    }
}

struct WindowCategoryView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Text("窗口")
                    .font(.headline)

                Text("配置终端窗口行为设置")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Image(systemName: "macwindow")
            }

            Section {
                Picker("初始窗口大小", selection: $viewModel.initialWindowSizeIndex) {
                    Text("自动").tag(0)
                    Text("固定大小").tag(1)
                }
                .pickerStyle(.menu)
            } header: {
                Text("初始窗口")
            }

            Section {
                Picker("窗口装饰", selection: $viewModel.windowDecorationIndex) {
                    Text("无").tag(0)
                    Text("标题栏").tag(1)
                    Text("完整").tag(2)
                }
                .pickerStyle(.menu)
            } header: {
                Text("窗口装饰")
            }

            Section {
                Toggle("记住窗口状态", isOn: $viewModel.windowSaveStateEnabled)
            } header: {
                Text("窗口状态")
            }
        }
        .formStyle(.grouped)
    }
}

struct KeybindingsCategoryView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Text("键盘绑定")
                    .font(.headline)

                Text("配置快捷键和操作绑定")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Image(systemName: "command")
            }

            Section {
                Text("键盘绑定编辑器")
                    .foregroundColor(.secondary)

                NavigationLink("打开键盘绑定设置") {
                    Text("配置键盘绑定")
                        .foregroundColor(.accentColor)
                }
            } header: {
                Text("自定义绑定")
            }

            Section {
                Toggle("允许全局快捷键", isOn: $viewModel.globalShortcutsEnabled)
            } header: {
                Text("全局快捷键")
            }
        }
        .formStyle(.grouped)
    }
}

struct AdvancedCategoryView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Text("高级")
                    .font(.headline)

                Text("配置高级终端设置")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Image(systemName: "gearshape")
            }

            Section {
                Picker("Shell 集成", selection: $viewModel.shellIntegrationIndex) {
                    Text("禁用").tag(0)
                    Text("基本").tag(1)
                    Text("完全").tag(2)
                }
                .pickerStyle(.menu)
            } header: {
                Text("Shell 集成")
            }

            Section {
                Toggle("启用快速终端", isOn: $viewModel.quickTerminalEnabled)
            } header: {
                Text("快速终端")
            }

            Section {
                Toggle("显示调试信息", isOn: $viewModel.debugLoggingEnabled)
            } header: {
                Text("调试")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Sidebar

struct ConfigurationSidebar: View {
    @Binding var selectedCategory: SettingsCategory

    var body: some View {
        List(SettingsCategory.allCases, id: \.self, selection: $selectedCategory) { category in
            Label(title: {
                Label(systemImage: category.iconName)
                Text(category.displayName)
            })
            .tag(category)
        }
        .listRowBackground(
            selectedCategory == category ?
                Color.accentColor.opacity(0.2) :
                Color.clear
        )
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @EnvironmentObject private var appDelegate: AppDelegate
    @State private var selectedCategory: SettingsCategory = .appearance
    @StateObject private var viewModel: SettingsViewModel

    @FocusState private var isSearchFocused: Bool?
    @State private var searchText: String = ""

    init() {
        // Initialize the view model
        let config = Ghostty.Config(at: nil, finalize: true)
        _viewModel = StateObject(wrappedValue: SettingsViewModel(config: config))
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            ConfigurationSidebar(selectedCategory: $selectedCategory)
                .navigationSplitViewColumnWidth(
                    min: 180,
                    ideal: 200,
                    max: 250
                )

            // Content area with toolbar
            VStack(spacing: 0) {
                // Toolbar with search and action buttons
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: selectedCategory.iconName)
                            .foregroundColor(.accentColor)
                        Text(selectedCategory.displayName)
                            .font(.headline)
                    }

                    Spacer()

                    // Search field
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.body)
                        TextField("搜索", text: $searchText)
                            .textFieldStyle(.plain)
                            .focused($isSearchFocused)
                            .frame(maxWidth: 200)
                    }
                    .padding(6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)

                    // Action buttons
                    HStack(spacing: 8) {
                        Button {
                            viewModel.cancel()
                            searchText = ""
                        } label: {
                            Text("取消")
                                .foregroundColor(.secondary)
                        }
                        .keyboardShortcut(.escape, modifiers: [])

                        Button {
                            if viewModel.save() {
                                // Close settings window after save
                                NSApp.keyWindow?.close()
                            }
                        } label: {
                            Text("保存")
                                .foregroundColor(viewModel.hasUnsavedChanges ? .accentColor : .secondary)
                        }
                        .keyboardShortcut(.return, modifiers: [.command])
                        .disabled(!viewModel.hasUnsavedChanges)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(nsColor: .separatorColor).opacity(0.5))

                // Content
                Group {
                    switch selectedCategory {
                    case .appearance:
                        AppearanceCategoryView(viewModel: viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .font:
                        FontCategoryView(viewModel: viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .colors:
                        ColorsCategoryView(viewModel: viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .terminal:
                        TerminalCategoryView(viewModel: viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .window:
                        WindowCategoryView(viewModel: viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .keybindings:
                        KeybindingsCategoryView(viewModel: viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .advanced:
                        AdvancedCategoryView(viewModel: viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minWidth: 400, maxWidth: 600)
            }
        }
        .frame(minWidth: 650, minHeight: 450)
        .onAppear {
            // Load current configuration values
            viewModel.loadValuesFromConfig()
        }
    }
}

// MARK: - Previews

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
