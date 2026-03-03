import Cocoa
import SwiftUI
import GhosttyKit

/// Settings window controller for Ghostty configuration.
class SettingsController: NSWindowController {
    /// Singleton for settings window.
    static let shared = SettingsController()

    /// The settings view model shared across all settings views
    private(set) var viewModel: SettingsViewModel?

    private override init(window: NSWindow?) {
        super.init(window: window)
        setupWindow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWindow() {
        // Create the settings view model
        let config = Ghostty.Config(at: nil, finalize: true)
        let model = SettingsViewModel(config: config)
        self.viewModel = model

        // Create a SwiftUI window with the view model
        let contentView = SettingsView()
            .environmentObject(model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 850, height: 600)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 850, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ghostty 设置"
        window.center()
        window.contentView = hostingController.view

        // Set up delegate to handle window close
        window.delegate = self

        self.window = window
    }

    /// Show the settings window.
    override func showWindow(_ sender: Any?) {
        // Reload configuration from disk to get latest values
        reloadConfiguration()

        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Reload the configuration from disk.
    private func reloadConfiguration() {
        // Load latest config values into existing viewModel
        // to preserve the @EnvironmentObject relationship
        let config = Ghostty.Config(at: nil, finalize: true)
        viewModel?.loadValuesFromConfig()
    }

    /// Save configuration changes.
    func saveChanges() -> Bool {
        guard let viewModel = viewModel else {
            showAlert(message: "无法保存设置：未找到视图模型")
            return false
        }

        return viewModel.save()
    }

    /// Cancel configuration changes.
    func cancelChanges() {
        guard let viewModel = viewModel else { return }
        viewModel.cancel()
    }
}

// MARK: - NSWindowDelegate

extension SettingsController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let viewModel = viewModel else { return true }

        if viewModel.hasUnsavedChanges {
            // Show alert for unsaved changes
            let alert = NSAlert()
            alert.messageText = "保存更改？"
            alert.informativeText = "您有未保存的更改。是否要在关闭前保存？"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "保存")
            alert.addButton(withTitle: "不保存")
            alert.addButton(withTitle: "取消")

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                // Save
                if saveChanges() {
                    return true
                } else {
                    showAlert(message: "保存失败，请重试")
                    return false
                }
            case .alertSecondButtonReturn:
                // Don't save
                cancelChanges()
                return true
            default:
                // Cancel close
                return false
            }
        }

        return true
    }

    func windowWillClose(_ notification: Notification) {
        // Reload configuration to reset unsaved changes state
        // Don't set viewModel to nil to keep the environment object intact
        if let viewModel = viewModel {
            viewModel.loadValuesFromConfig()
        }
    }

    /// Show an alert with the given message.
    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "错误"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}
