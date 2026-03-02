import SwiftUI
import GhosttyKit

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

    /// Line spacing
    @Published var lineSpacing: Double = 0 {
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

    /// Scrollback buffer size
    @Published var scrollbackLines: Int = 10000 {
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

        // Load font settings
        // Note: These would need to be added to the Config class
        // For now using defaults

        // Load color settings
        let fg = config.backgroundColor // Using background as fallback
        foregroundColor = fg
        backgroundColor = config.backgroundColor

        // Load terminal settings
        // Note: cursor-style would need to be added to Config class

        // Load completion settings
        config.getBool("completion-enabled", &completionEnabled)
        config.getInt("completion-min-chars", &completionMinChars)

        let completionModeStr = config.getString("completion-mode")
        if completionModeStr == "inline" {
            completionModeIndex = 0
        } else {
            completionModeIndex = 1 // default to menu
        }

        // Load window settings
        windowSaveStateEnabled = config.windowSaveState != "never"

        // Load advanced settings
        // Note: These would need specific config keys
    }

    // MARK: - Change Tracking

    private func markChanged() {
        hasUnsavedChanges = true
    }

    // MARK: - Save/Cancel

    /// Save all changes to the configuration file
    func save() -> Bool {
        // Build settings dictionary
        var settings: [String: String] = [:]
        settings["completion-enabled"] = completionEnabled ? "true" : "false"
        settings["completion-min-chars"] = String(completionMinChars)
        settings["completion-mode"] = completionModeIndex == 0 ? "inline" : "menu"

        // Save to file
        let success = config.save(settings: settings)
        if !success {
            errorMessage = "保存配置失败，请检查文件权限"
            return false
        }

        errorMessage = nil
        hasUnsavedChanges = false
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
        // Update completion settings
        config.setBool("completion-enabled", completionEnabled)
        config.setInt("completion-min-chars", Int32(completionMinChars))

        let completionModeValue = completionModeIndex == 0 ? "inline" : "menu"
        config.setString("completion-mode", completionModeValue)

        // Update other settings
        // This would use ghostty_config_set for each key
        // For now this is a placeholder for the pattern
    }

    // MARK: - Preview Support

    /// Create a preview configuration without saving
    func createPreviewConfig() -> Ghostty.Config? {
        // Clone the current config and apply pending changes
        // This would be used for live preview
        return nil
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
