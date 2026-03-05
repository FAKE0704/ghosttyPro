import SwiftUI
import GhosttyKit

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
            Section("窗口透明度") {
                VStack(alignment: .leading) {
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
                }
            }

            Section("主题") {
                Picker("主题", selection: $viewModel.themeIndex) {
                    ForEach(0..<SettingsViewModel.themeOptions.count, id: \.self) { index in
                        Text(SettingsViewModel.themeOptions[index].displayName)
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("背景模糊") {
                Toggle("背景模糊", isOn: $viewModel.backgroundBlurEnabled)
            }
        }
        .formStyle(.grouped)
    }
}

struct FontCategoryView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Preview area at the top - shows all font settings
            previewSection

            Divider()

            // Configuration options below
            configurationSection
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("字体预览")
                .font(.caption)
                .foregroundColor(.secondary)

            // Create a preview that reflects all current font settings
            VStack(alignment: .leading, spacing: 4) {
                // English preview
                Text("The quick brown fox jumps over the lazy dog.")
                    .font(.custom(
                        SettingsViewModel.fontFamilyOptions[viewModel.fontFamilyIndex],
                        size: viewModel.fontSize
                    ))

                // Chinese preview
                Text("敏捷的棕色狐狸跳过了懒惰的狗。")
                    .font(.custom(
                        SettingsViewModel.fontFamilyOptions[viewModel.fontFamilyIndex],
                        size: viewModel.fontSize
                    ))

                // Numbers and symbols preview
                Text("0123456789 !@#$%^&*()")
                    .font(.custom(
                        SettingsViewModel.fontFamilyOptions[viewModel.fontFamilyIndex],
                        size: viewModel.fontSize
                    ))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var configurationSection: some View {
        ScrollView {
            Form {
                Section("字体系列") {
                    Picker("字体系列", selection: $viewModel.fontFamilyIndex) {
                        ForEach(0..<SettingsViewModel.fontFamilyOptions.count, id: \.self) { index in
                            Text(SettingsViewModel.fontFamilyOptions[index])
                                .tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("字体大小") {
                    VStack(alignment: .leading) {
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
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}

struct ColorsCategoryView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Text("颜色设置功能开发中...")
                    .foregroundColor(.secondary)
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
                HStack {
                    Text("光标样式")
                    Spacer()
                    Picker("", selection: $viewModel.cursorStyleIndex) {
                        Text("块").tag(0)
                        Text("下划线").tag(1)
                        Text("竖线").tag(2)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }

            Section("滚动历史") {
                HStack {
                    Text("滚动距离")
                    Spacer()
                    Stepper("", value: $viewModel.scrollbackLines, in: 0...100000, step: 100)
                        .labelsHidden()
                }
            }

            Section("智能补全") {
                Toggle("启用智能补全", isOn: $viewModel.completionEnabled)

                if viewModel.completionEnabled {
                    HStack {
                        Text("补全模式")
                        Spacer()
                        Picker("", selection: $viewModel.completionModeIndex) {
                            Text("仅灰色提示").tag(0)
                            Text("菜单模式").tag(1)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    HStack {
                        Text("最少触发字符数")
                        Spacer()
                        Stepper("", value: $viewModel.completionMinChars, in: 1...10)
                            .labelsHidden()
                        Text("\(viewModel.completionMinChars)")
                            .foregroundColor(.secondary)
                            .frame(width: 30)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct WindowCategoryView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("初始窗口") {
                HStack {
                    Text("初始窗口大小")
                    Spacer()
                    Picker("", selection: $viewModel.initialWindowSizeIndex) {
                        Text("自动").tag(0)
                        Text("固定大小").tag(1)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }

            Section("窗口装饰") {
                HStack {
                    Text("窗口装饰")
                    Spacer()
                    Picker("", selection: $viewModel.windowDecorationIndex) {
                        Text("无").tag(0)
                        Text("标题栏").tag(1)
                        Text("完整").tag(2)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }

            Section("窗口状态") {
                Toggle("记住窗口状态", isOn: $viewModel.windowSaveStateEnabled)
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
                Text("键盘绑定功能开发中...")
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct AdvancedCategoryView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Shell 集成") {
                HStack {
                    Text("Shell 集成")
                    Spacer()
                    Picker("", selection: $viewModel.shellIntegrationIndex) {
                        Text("禁用").tag(0)
                        Text("基本").tag(1)
                        Text("完全").tag(2)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }

            Section("快速终端") {
                Toggle("启用快速终端", isOn: $viewModel.quickTerminalEnabled)
            }

            Section("调试") {
                Toggle("显示调试信息", isOn: $viewModel.debugLoggingEnabled)
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
            Label {
                Text(category.displayName)
            } icon: {
                Image(systemName: category.iconName)
            }
            .tag(category)
            .listRowBackground(
                selectedCategory == category ?
                    Color.accentColor.opacity(0.2) :
                    Color.clear
            )
        }
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @EnvironmentObject private var appDelegate: AppDelegate
    @State private var selectedCategory: SettingsCategory = .appearance
    @StateObject private var viewModel: SettingsViewModel

    @FocusState private var isSearchFocused: Bool
    @State private var searchText: String = ""
    @State private var showingResetConfirmation = false

    init() {
        // Initialize the view model with a temporary config
        // The actual config will be loaded in onAppear
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

        } detail: {
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
                            showingResetConfirmation = true
                        } label: {
                            Text("还原默认")
                                .foregroundColor(.red)
                        }

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
        .alert("还原默认配置", isPresented: $showingResetConfirmation) {
            Button("取消", role: .cancel) { }
            Button("确认还原", role: .destructive) {
                if viewModel.deleteUserConfig() {
                    // Show success message and close settings window
                    NSApp.keyWindow?.close()
                }
            }
        } message: {
            Text("此操作将删除您的配置文件并将所有设置还原为默认值。此操作不可撤销。\n\n确定要继续吗？")
        }
    }
}

// MARK: - Previews

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
