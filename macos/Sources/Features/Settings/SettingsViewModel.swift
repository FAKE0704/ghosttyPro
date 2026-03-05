import SwiftUI
import AppKit
import GhosttyKit
import OSLog
import Foundation

/// ViewModel for managing Ghostty settings interface.
/// Bridges SwiftUI views with the underlying Ghostty configuration system.
@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The current configuration being edited
    @Published private(set) var config: Ghostty.Config

    /// Whether there are unsaved changes
    @Published private(set) var hasUnsavedChanges: Bool = false

    /// Current error message, if any
    @Published private(set) var errorMessage: String? = nil

    // MARK: - Appearance Settings

    /// Window opacity (0.0 - 1.0)
    @Published var windowOpacity: Double = 1.0 {
        didSet { markChanged() }
    }

    /// Theme selection
    @Published var themeIndex: Int = 0 {
        didSet { markChanged() }
    }

    /// Background blur enabled
    @Published var backgroundBlurEnabled: Bool = false {
        didSet { markChanged() }
    }

    // MARK: - Font Settings

    /// Font family index
    @Published var fontFamilyIndex: Int = 0 {
        didSet { markChanged() }
    }

    /// Font size in points
    @Published var fontSize: Double = 13 {
        didSet { markChanged() }
    }


    // MARK: - Color Settings

    /// Foreground color
    @Published var foregroundColor: Color = .primary {
        didSet { markChanged() }
    }

    /// Background color
    @Published var backgroundColor: Color = .primary {
        didSet { markChanged() }
    }

    /// Cursor color
    @Published var cursorColor: Color = .primary {
        didSet { markChanged() }
    }

    /// Use custom palette
    @Published var useCustomPalette: Bool = false {
        didSet { markChanged() }
    }

    // MARK: - Terminal Settings

    /// Cursor style index (0=block, 1=underline, 2=bar)
    @Published var cursorStyleIndex: Int = 0 {
        didSet { markChanged() }
    }

    /// Scrollback buffer size (in approximate lines)
    @Published var scrollbackLines: Int = 100000 {
        didSet { markChanged() }
    }

    /// Completion enabled
    @Published var completionEnabled: Bool = false {
        didSet { markChanged() }
    }

    /// Completion mode (0=inline, 1=menu)
    @Published var completionModeIndex: Int = 1 {
        didSet { markChanged() }
    }

    /// Minimum characters before triggering completion
    @Published var completionMinChars: Int = 1 {
        didSet { markChanged() }
    }

    // MARK: - Window Settings

    /// Initial window size (0=auto, 1=fixed)
    @Published var initialWindowSizeIndex: Int = 0 {
        didSet { markChanged() }
    }

    /// Window decoration (0=none, 1=titlebar, 2=full)
    @Published var windowDecorationIndex: Int = 1 {
        didSet { markChanged() }
    }

    /// Remember window state
    @Published var windowSaveStateEnabled: Bool = true {
        didSet { markChanged() }
    }

    // MARK: - Keybindings Settings

    /// Global shortcuts enabled
    @Published var globalShortcutsEnabled: Bool = true {
        didSet { markChanged() }
    }

    // MARK: - Advanced Settings

    /// Shell integration (0=disabled, 1=basic, 2=full)
    @Published var shellIntegrationIndex: Int = 1 {
        didSet { markChanged() }
    }

    /// Quick terminal enabled
    @Published var quickTerminalEnabled: Bool = false {
        didSet { markChanged() }
    }

    /// Debug logging enabled
    @Published var debugLoggingEnabled: Bool = false {
        didSet { markChanged() }
    }

    // MARK: - Static Options

    private(set) static var themeOptions: [ThemeOption] = [
        ThemeOption(displayName: "跟随系统", value: "auto"),
        ThemeOption(displayName: "亮色", value: "light"),
        ThemeOption(displayName: "暗色", value: "dark"),
    ]

    private(set) static var fontFamilyOptions: [String] = [
        "Menlo",
        "Monaco",
        "SF Mono",
        "JetBrains Mono",
        "Fira Code",
        "Source Code Pro",
    ]

    // MARK: - Initialization

    init(config: Ghostty.Config) {
        self.config = config
        loadValuesFromConfig()
    }

    convenience init() {
        let cfg = Ghostty.Config(at: nil, finalize: true)
        self.init(config: cfg)
    }

    // MARK: - Configuration Loading

    /// Load all configuration values into the view model properties
    func loadValuesFromConfig() {
        // Load appearance settings
        windowOpacity = config.backgroundOpacity
        backgroundBlurEnabled = config.backgroundBlur.isEnabled

        // Load theme
        if let themeStr = config.getString("theme") {
            if themeStr.contains("light") {
                themeIndex = 1
            } else if themeStr.contains("dark") {
                themeIndex = 2
            } else {
                themeIndex = 0 // auto/system
            }
        }

        // Load font settings
        if let fontSizeValue = config.getDouble("font-size") {
            fontSize = max(8, min(72, fontSizeValue))
        } else {
            fontSize = 13
        }

        if let fontFamilyStr = config.getString("font-family") {
            // Try to find the font family in our options
            if let index = SettingsViewModel.fontFamilyOptions.firstIndex(where: { $0 == fontFamilyStr }) {
                fontFamilyIndex = index
            } else {
                // Reset to default if font family not found in options
                fontFamilyIndex = 0
            }
        } else {
            // Use default (Menlo)
            fontFamilyIndex = 0
        }

        // Load color settings
        let fg = config.backgroundColor // Using background as fallback
        foregroundColor = fg
        backgroundColor = config.backgroundColor

        // Load terminal settings
        if let cursorStyleStr = config.getString("cursor-style") {
            switch cursorStyleStr {
            case "underline":
                cursorStyleIndex = 1
            case "bar":
                cursorStyleIndex = 2
            default:
                cursorStyleIndex = 0 // block
            }
        }

        // scrollback-limit is in bytes, convert to approximate lines
        // Default is 10000000 bytes, we'll map this differently
        // For now use a simple approximation
        if let scrollbackLimit = config.getInt("scrollback-limit"), scrollbackLimit > 0 {
            // Convert bytes to approximate line count (assuming ~100 chars per line)
            scrollbackLines = max(1000, min(100000, scrollbackLimit / 100))
        } else {
            // Default: 10000000 bytes = 100000 lines approximately
            scrollbackLines = 100000
        }

        // Load completion settings
        var completionEnabledValue = false
        config.getBool("completion-enabled", &completionEnabledValue)
        completionEnabled = completionEnabledValue

        var completionMinCharsValue = 1
        config.getInt("completion-min-chars", &completionMinCharsValue)
        completionMinChars = max(1, min(10, completionMinCharsValue))

        let completionModeStr = config.getString("completion-mode")
        if completionModeStr == "inline" {
            completionModeIndex = 0
        } else {
            completionModeIndex = 1 // default to menu
        }

        // Load window settings
        var initialWindow = true
        config.getBool("initial-window", &initialWindow)
        initialWindowSizeIndex = initialWindow ? 0 : 1

        // Map window-decoration to index
        // Config returns a Bool for enabled, but we need the actual string value
        if let decorationStr = config.getString("window-decoration") {
            switch decorationStr {
            case "none":
                windowDecorationIndex = 0
            case "client", "auto":
                windowDecorationIndex = 1
            case "server":
                windowDecorationIndex = 2
            default:
                windowDecorationIndex = 1
            }
        }

        windowSaveStateEnabled = config.windowSaveState != "never"

        // Load advanced settings
        // Shell integration
        if let shellIntegrationStr = config.getString("shell-integration") {
            switch shellIntegrationStr {
            case "none":
                shellIntegrationIndex = 0
            default:
                shellIntegrationIndex = 1 // detect is default
            }
        }

        // Note: quickTerminalEnabled and debugLoggingEnabled don't have direct config keys
        // quick-terminal is controlled by quick-terminal-position etc.
    }

    // MARK: - Change Tracking

    private func markChanged() {
        hasUnsavedChanges = true
    }

    // MARK: - Save/Cancel

    /// Save all changes to the configuration file
    func save() -> Bool {
        // Cancel any pending preview updates
        cancelPendingPreview()

        // First update the in-memory config object
        updateConfigFromViewModel()

        // Build settings dictionary for file persistence
        var settings: [String: String] = [:]

        // Appearance settings
        settings["background-opacity"] = String(format: "%.2f", windowOpacity)
        let backgroundBlurValue: String
        switch backgroundBlurEnabled {
        case true:
            // Determine which blur mode to use based on macOS version
            if #available(macOS 26.0, *) {
                backgroundBlurValue = "-1" // macosGlassRegular
            } else {
                backgroundBlurValue = "20" // fallback radius
            }
        case false:
            backgroundBlurValue = "0"
        }
        settings["background-blur"] = backgroundBlurValue

        // Theme: only save if explicitly set to light or dark
        // "auto" (index 0) means use system default, so don't set theme config
        switch themeIndex {
        case 1:
            settings["theme"] = "light"
        case 2:
            settings["theme"] = "dark"
        default:
            // case 0 (auto/system) - don't set theme, use default behavior
            break
        }

        // Font settings
        if fontFamilyIndex >= 0 && fontFamilyIndex < SettingsViewModel.fontFamilyOptions.count {
            settings["font-family"] = SettingsViewModel.fontFamilyOptions[fontFamilyIndex]
        }

        // Ensure font size is valid before saving
        let validFontSize = max(8, min(72, fontSize))
        settings["font-size"] = String(format: "%.1f", validFontSize)

        // Terminal settings
        let cursorStyleValue: String
        switch cursorStyleIndex {
        case 1:
            cursorStyleValue = "underline"
        case 2:
            cursorStyleValue = "bar"
        default:
            cursorStyleValue = "block"
        }
        settings["cursor-style"] = cursorStyleValue

        // Convert lines back to bytes (approximately)
        // Ensure scrollback lines is within valid range
        let validScrollbackLines = max(1000, min(100000, scrollbackLines))
        settings["scrollback-limit"] = String(validScrollbackLines * 100)

        // Completion settings
        settings["completion-enabled"] = completionEnabled ? "true" : "false"

        // Ensure completion min chars is within valid range
        let validMinChars = max(1, min(10, completionMinChars))
        settings["completion-min-chars"] = String(validMinChars)
        settings["completion-mode"] = completionModeIndex == 0 ? "inline" : "menu"

        // Window settings
        settings["initial-window"] = initialWindowSizeIndex == 0 ? "true" : "false"

        let windowDecorationValue: String
        switch windowDecorationIndex {
        case 0:
            windowDecorationValue = "none"
        case 1:
            windowDecorationValue = "auto"
        case 2:
            windowDecorationValue = "server"
        default:
            windowDecorationValue = "auto"
        }
        settings["window-decoration"] = windowDecorationValue

        settings["window-save-state"] = windowSaveStateEnabled ? "default" : "never"

        // Advanced settings
        let shellIntegrationValue: String
        switch shellIntegrationIndex {
        case 0:
            shellIntegrationValue = "none"      // disabled
        case 1, 2:
            shellIntegrationValue = "detect"    // basic or full (auto-detect)
        default:
            shellIntegrationValue = "detect"
        }
        settings["shell-integration"] = shellIntegrationValue

        // Save to file
        let success = config.save(settings: settings)
        if !success {
            errorMessage = "保存配置失败，请检查文件权限"
            return false
        }

        errorMessage = nil
        hasUnsavedChanges = false

        // Reload the config to get the new values
        let newConfig = Ghostty.Config(at: nil, finalize: true)
        self.config = newConfig

        // Get the app instance to update config at the底层 level
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate,
              let app = appDelegate.ghostty.app else {
            // Fallback: just post notification
            NotificationCenter.default.post(
                name: .ghosttyConfigDidChange,
                object: nil,
                userInfo: [
                    Notification.Name.GhosttyConfigChangeKey: newConfig,
                ]
            )
            return true
        }

        // Update the app-level config directly using the C API
        // This will propagate to all surfaces
        ghostty_app_update_config(app, newConfig.config!)

        // Post notification to update UI elements
        NotificationCenter.default.post(
            name: .ghosttyConfigDidChange,
            object: nil,
            userInfo: [
                Notification.Name.GhosttyConfigChangeKey: newConfig,
            ]
        )

        return true
    }

    /// Cancel all unsaved changes
    func cancel() {
        loadValuesFromConfig()
        hasUnsavedChanges = false
        errorMessage = nil
    }

    /// Apply ViewModel changes back to the config
    private func updateConfigFromViewModel() {
        // Update appearance settings
        config.setDouble("background-opacity", windowOpacity)

        let backgroundBlurValue: Int32
        switch backgroundBlurEnabled {
        case true:
            // Determine which blur mode to use based on macOS version
            if #available(macOS 26.0, *) {
                backgroundBlurValue = -1 // macosGlassRegular
            } else {
                backgroundBlurValue = 20 // fallback radius
            }
        case false:
            backgroundBlurValue = 0
        }
        config.setInt("background-blur", backgroundBlurValue)

        // Theme: only set if explicitly choosing light or dark
        // "auto" (index 0) means use system default, so don't set theme
        switch themeIndex {
        case 1:
            config.setString("theme", "light")
        case 2:
            config.setString("theme", "dark")
        default:
            // case 0 (auto/system) - don't set theme, let it use default
            break
        }

        // Update font settings
        if fontFamilyIndex >= 0 && fontFamilyIndex < SettingsViewModel.fontFamilyOptions.count {
            config.setString("font-family", SettingsViewModel.fontFamilyOptions[fontFamilyIndex])
        }

        // Ensure font size is valid before setting
        let validFontSize = max(8, min(72, fontSize))
        config.setDouble("font-size", validFontSize)

        // Update terminal settings
        let cursorStyleValue: String
        switch cursorStyleIndex {
        case 1:
            cursorStyleValue = "underline"
        case 2:
            cursorStyleValue = "bar"
        default:
            cursorStyleValue = "block"
        }
        config.setString("cursor-style", cursorStyleValue)

        // Ensure scrollback lines is within valid range
        let validScrollbackLines = max(1000, min(100000, scrollbackLines))
        config.setInt("scrollback-limit", Int32(validScrollbackLines * 100))

        // Update completion settings
        config.setBool("completion-enabled", completionEnabled)

        // Ensure completion min chars is within valid range
        let validMinChars = max(1, min(10, completionMinChars))
        config.setInt("completion-min-chars", Int32(validMinChars))

        let completionModeValue = completionModeIndex == 0 ? "inline" : "menu"
        config.setString("completion-mode", completionModeValue)

        // Update window settings
        config.setBool("initial-window", initialWindowSizeIndex == 0)

        let windowDecorationValue: String
        switch windowDecorationIndex {
        case 0:
            windowDecorationValue = "none"
        case 1:
            windowDecorationValue = "auto"
        case 2:
            windowDecorationValue = "server"
        default:
            windowDecorationValue = "auto"
        }
        config.setString("window-decoration", windowDecorationValue)

        config.setString("window-save-state", windowSaveStateEnabled ? "default" : "never")

        // Update advanced settings
        let shellIntegrationValue = shellIntegrationIndex == 0 ? "none" : "detect"
        config.setString("shell-integration", shellIntegrationValue)
    }

    // MARK: - Preview Support

    /// Timer for debouncing font size preview
    private var previewDebounceTimer: DispatchWorkItem?

    /// Preview font size change in real-time with debouncing
    func previewFontSizeChange(_ newSize: Double) {
        // Cancel any pending preview
        previewDebounceTimer?.cancel()

        // Create a new debounced task
        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.applyFontSizePreview(newSize)
        }

        previewDebounceTimer = task

        // Execute after a short delay (150ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: task)
    }

    /// Apply the font size preview to all terminals
    private func applyFontSizePreview(_ newSize: Double) {
        // Preview is now handled in the settings UI with example text
        // No need to update terminal surfaces during preview
    }

    /// Cancel any pending preview updates
    func cancelPendingPreview() {
        previewDebounceTimer?.cancel()
        previewDebounceTimer = nil
    }

    /// Create a preview configuration without saving
    func createPreviewConfig() -> Ghostty.Config? {
        // Clone the current config and apply pending changes
        // This would be used for live preview
        return nil
    }

    /// Reset all settings to their default values
    func resetToDefaults() {
        // Reset appearance settings
        windowOpacity = 1.0
        themeIndex = 0  // auto
        backgroundBlurEnabled = false

        // Reset font settings
        fontFamilyIndex = 0  // Menlo
        fontSize = 13  // default on macOS

        // Reset terminal settings
        cursorStyleIndex = 0  // block
        scrollbackLines = 100000  // 10MB / 100 chars per line
        completionEnabled = false
        completionModeIndex = 1  // menu
        completionMinChars = 1

        // Reset window settings
        initialWindowSizeIndex = 0  // auto
        windowDecorationIndex = 1  // auto
        windowSaveStateEnabled = true

        // Reset advanced settings
        shellIntegrationIndex = 1  // detect

        hasUnsavedChanges = true
    }

    /// Delete user configuration file and reset to defaults
    func deleteUserConfig() -> Bool {
        let logger = Logger(subsystem: "com.mitchellh.ghostty", category: "Config")

        // Get the config file path
        let path = ghostty_config_open_path()
        defer {
            ghostty_string_free(path)
        }
        guard let pathPtr = path.ptr else { return false }
        let configPath = String(cString: pathPtr)

        // Check if file exists
        guard FileManager.default.fileExists(atPath: configPath) else {
            // File doesn't exist, nothing to delete
            return true
        }

        // Delete the file
        do {
            try FileManager.default.removeItem(atPath: configPath)
            logger.info("Configuration file deleted: \(configPath)")

            // Reload the config to get defaults
            let defaultConfig = Ghostty.Config(at: nil, finalize: true)
            self.config = defaultConfig
            loadValuesFromConfig()

            hasUnsavedChanges = false
            return true
        } catch {
            logger.error("Failed to delete config: \(error)")
            errorMessage = "删除配置文件失败：\(error.localizedDescription)"
            return false
        }
    }
}

// MARK: - Supporting Types

extension SettingsViewModel {
    struct ThemeOption: Hashable {
        let displayName: String
        let value: String
    }
}

// MARK: - Color Conversion Extensions

extension Color {
    /// Initialize from a ghostty_config_color_s
    init(ghostty color: ghostty_config_color_s) {
        self.init(
            red: Double(color.r) / 255,
            green: Double(color.g) / 255,
            blue: Double(color.b) / 255
        )
    }

    /// Convert to ghostty_config_color_s
    func toGhosttyColor() -> ghostty_config_color_s {
        var result = ghostty_config_color_s()
#if os(macOS)
        let nsColor = NSColor(self)
        // Convert to RGB
        let red = Float(nsColor.redComponent * 255)
        let green = Float(nsColor.greenComponent * 255)
        let blue = Float(nsColor.blueComponent * 255)
        result.r = UInt8(red.clamped(to: 0...255))
        result.g = UInt8(green.clamped(to: 0...255))
        result.b = UInt8(blue.clamped(to: 0...255))
#else
        // Fallback for other platforms
        result.r = 255
        result.g = 255
        result.b = 255
#endif
        return result
    }
}

// MARK: - Comparable Extensions

extension Color {
    /// Check if this is a light color (for UI decisions)
    var isLightColor: Bool {
#if os(macOS)
        let nsColor = NSColor(self)
        // Extract components ensuring we're in RGB color space
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Calculate perceived brightness using the formula for relative luminance
        let brightness = (0.299 * red + 0.587 * green + 0.114 * blue)
        return brightness > 0.5
#else
        return true
#endif
    }

    /// Darken this color by a percentage
    func darken(by percentage: CGFloat) -> Color {
#if os(macOS)
        let nsColor = NSColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let factor = 1.0 - percentage
        return Color(
            red: red * factor,
            green: green * factor,
            blue: blue * factor,
            opacity: alpha
        )
#else
        return self
#endif
    }
}

// MARK: - Float Extensions

extension BinaryFloatingPoint {
    /// Clamp value to a range
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
