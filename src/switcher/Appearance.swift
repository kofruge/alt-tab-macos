import Cocoa

class Appearance {
    // size
    static var resolvedSize = AppearanceSizePreference.medium
    static var hideThumbnails = Bool(false)
    static var windowPadding = CGFloat(1000)
    static var windowCornerRadius = CGFloat(1000)
    static var cellCornerRadius = CGFloat(1000)
    static var edgeInsetsSize = CGFloat(1000)
    static var maxWidthOnScreen = CGFloat(1000)
    static var rowsCount = CGFloat(1000)
    static var iconSize = CGFloat(1000)
    static var fontHeight = CGFloat(3)
    static var font = NSFont.systemFont(ofSize: fontHeight)
    static var windowMinWidthInRow = CGFloat(1000)
    static var windowMaxWidthInRow = CGFloat(1000)

    // size: constants
    /// What: Maximum proportion of visible screen height the switcher panel is allowed to occupy (96%).
    /// Why: Permits high-density single-column lists (mini-mode) to maximize visible item count without clipping the menu bar or dock.
    static let maxHeightOnScreen = CGFloat(0.96)
    static let interCellPadding = CGFloat(1)
    static let intraCellPadding = CGFloat(5)
    /// What: Spacing between the application icon and the title label (4 pt).
    /// Why: Provides tailored legibility and proportional spacing in compact titles-style list rows.
    static let appIconLabelSpacing = CGFloat(4)

    // theme
    static var fontColor = NSColor.red
    static var imagesShadowColor = NSColor.red // for icon, thumbnail and windowless images
    static var material = LegacyMaterial.ultraDark
    static var highlightBorderWidth = CGFloat(3)

    // theme: constants
    static var enablePanelShadow = true
    static var highlightFocusedBackgroundColor: NSColor { get { NSColor.systemAccentColor.withAlphaComponent(0.2) } }
    static var highlightHoveredBackgroundColor: NSColor { get { NSColor.systemAccentColor.withAlphaComponent(0.1) } }
    static var highlightFocusedBorderColor: NSColor { get { NSColor.systemAccentColor } }
    static var highlightHoveredBorderColor: NSColor { get { NSColor.systemAccentColor.withAlphaComponent(0.7) } }
    static var searchMatchHighlightColor: NSColor { get { NSColor.systemYellow.withAlphaComponent(0.5) } }
    static var searchMatchForegroundColor: NSColor { get { NSColor(calibratedWhite: 0.12, alpha: 1) } }

    private static var currentStyle: AppearanceStylePreference { Preferences.effectiveAppearanceStyle(SwitcherSession.activeShortcutIndex) }
    private static var currentSize: AppearanceSizePreference { Preferences.effectiveAppearanceSize(SwitcherSession.activeShortcutIndex) }
    static var currentTheme: AppearanceThemePreference {
        let theme = Preferences.effectiveAppearanceTheme(SwitcherSession.activeShortcutIndex)
        return theme == .system ? NSAppearance.currentDrawing().getThemeName() : theme
    }

    static func update() {
        updateSize()
        updateTheme()
    }

    private static func updateSize() {
        let isHorizontalScreen = NSScreen.preferred.isHorizontal()
        maxWidthOnScreen = AppearanceTestable.comfortableWidth(NSScreen.preferred.physicalSize().map { $0.width })
        let sizeToApply: AppearanceSizePreference = currentSize == .auto ? .large : currentSize
        resolvedSize = sizeToApply
        applyConcreteSize(sizeToApply, isHorizontalScreen)
        updateFont()
    }

    static func applySize(_ size: AppearanceSizePreference) {
        let isHorizontalScreen = NSScreen.preferred.isHorizontal()
        resolvedSize = size
        applyConcreteSize(size, isHorizontalScreen)
        updateFont()
    }

    private static func applyConcreteSize(_ size: AppearanceSizePreference, _ isHorizontalScreen: Bool) {
        if currentStyle == .appIcons {
            appIconsSize(size)
        } else if currentStyle == .titles {
            titlesSize(size)
        } else {
            thumbnailsSize(isHorizontalScreen, size)
        }
    }

    private static func updateTheme() {
        highlightBorderWidth = currentStyle == .titles ? 2 : 3
        if currentTheme == .dark {
            darkTheme()
        } else {
            lightTheme()
        }
        // for Liquid Glass, we don't want a shadow around the panel
        if #available(macOS 26.0, *), currentStyle == .appIcons && LiquidGlass.canUsePrivateLook {
            enablePanelShadow = false
        } else {
            enablePanelShadow = true
        }
    }

    private static func thumbnailsSize(_ isHorizontalScreen: Bool, _ size: AppearanceSizePreference) {
        hideThumbnails = false
        windowPadding = 18
        windowCornerRadius = 23
        cellCornerRadius = 10
        edgeInsetsSize = 12
        if #available(macOS 26.0, *) {
            windowPadding = 28
            windowCornerRadius = 43
            cellCornerRadius = 18
        }
        switch size {
            case .small:
                rowsCount = isHorizontalScreen ? 5 : 8
                iconSize = 16
                fontHeight = 13
            case .medium:
                rowsCount = isHorizontalScreen ? 4 : 7
                iconSize = 26
                fontHeight = 14
            case .large, .auto:
                rowsCount = isHorizontalScreen ? 3 : 6
                iconSize = 28
                fontHeight = 16
        }
        let tilesPanelRatio = (NSScreen.preferred.frame.width * maxWidthOnScreen) / (NSScreen.preferred.frame.height * maxHeightOnScreen)
        (windowMinWidthInRow, windowMaxWidthInRow) = AppearanceTestable.goodValuesForThumbnailsWidthMinMax(tilesPanelRatio, rowsCount)
    }

    private static func appIconsSize(_ size: AppearanceSizePreference) {
        hideThumbnails = true
        windowPadding = 25
        windowCornerRadius = 23
        cellCornerRadius = 10
        edgeInsetsSize = 5
        if #available(macOS 26.0, *) {
            edgeInsetsSize = 6
        }
        windowMinWidthInRow = 0.04
        windowMaxWidthInRow = 0.3
        rowsCount = 1
        switch size {
            case .small:
                iconSize = 70
                fontHeight = 13
                if #available(macOS 26.0, *) {
                    windowCornerRadius = 50
                    cellCornerRadius = 24
                }
            case .medium:
                iconSize = 110
                fontHeight = 14
                if #available(macOS 26.0, *) {
                    windowCornerRadius = 55
                    cellCornerRadius = 35
                }
            case .large, .auto:
                windowPadding = 28
                iconSize = 150
                fontHeight = 16
                if #available(macOS 26.0, *) {
                    windowCornerRadius = 75
                    cellCornerRadius = 45
                }
        }
    }

    /// Configures compact dimensions, corner radii, and typographic metrics for the `.titles` style (mini-mode).
    ///
    /// - What: Applies compact cell padding (8 pt window padding, 4 pt cell corners, 3 pt insets) and dense icon/font
    ///   pairings (16-20 pt icons with 12-13.5 pt typography) across size presets.
    /// - Why: Transforms the default wide thumbnail switcher into a streamlined, high-density vertical list view
    ///   optimized for rapid window scanning and keyboard/scroll wheel navigation.
    private static func titlesSize(_ size: AppearanceSizePreference) {
        hideThumbnails = true
        windowPadding = 8
        windowCornerRadius = 10
        cellCornerRadius = 4
        edgeInsetsSize = 3
        windowMinWidthInRow = 0.5
        windowMaxWidthInRow = 0.95
        rowsCount = 1
        switch size {
            case .small:
                iconSize = 16
                fontHeight = 12
            case .medium:
                iconSize = 18
                fontHeight = 13
            case .large, .auto:
                iconSize = 20
                fontHeight = 13.5
        }
    }

    private static func updateFont() {
        if #available(macOS 26.0, *) {
            font = NSFont.systemFont(ofSize: fontHeight, weight: currentStyle == .appIcons ? .semibold : .medium)
        } else {
            font = NSFont.systemFont(ofSize: fontHeight)
        }
    }

    private static func lightTheme() {
        fontColor = .black.withAlphaComponent(0.8)
        imagesShadowColor = .gray.withAlphaComponent(0.8)
        material = LegacyMaterial.mediumLight
    }

    private static func darkTheme() {
        fontColor = .white.withAlphaComponent(0.85)
        imagesShadowColor = .gray.withAlphaComponent(0.8)
        material = LegacyMaterial.dark
    }
}

/// The only `NSVisualEffectView.Material` values that pin light or dark explicitly. Deprecated in
/// 10.14 in favour of semantic materials, which we can't use: those follow the view's
/// `NSAppearance`, whereas our theme comes from the user's own preference (see `updateTheme`).
/// Referenced by rawValue because naming the cases trips `SWIFT_TREAT_WARNINGS_AS_ERRORS`.
enum LegacyMaterial {
    static let dark = NSVisualEffectView.Material(rawValue: 2)!
    static let mediumLight = NSVisualEffectView.Material(rawValue: 8)!
    static let ultraDark = NSVisualEffectView.Material(rawValue: 9)!
}
