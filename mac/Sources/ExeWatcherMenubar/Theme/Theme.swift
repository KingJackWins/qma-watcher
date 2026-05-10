import SwiftUI

/// Design tokens — Quantum Memory palette.
/// Monochrome purple — deep dark background with lavender/violet accents.
enum Theme {
    // Brand accent — QM Lavender (#A78BFA)
    static let brandAccent       = Color(red: 0xA7/255.0, green: 0x8B/255.0, blue: 0xFA/255.0)
    // Hover / lighter lavender (#C4B5FD)
    static let brandAccentDark   = Color(red: 0xC4/255.0, green: 0xB5/255.0, blue: 0xFD/255.0)
    // Mid purple for depth/glow (#7C3AED)
    static let brandEmberDeep    = Color(red: 0x7C/255.0, green: 0x3A/255.0, blue: 0xED/255.0)
    // Dark purple for text on light purple backgrounds (#1E1035)
    static let brandPurpleDark   = Color(red: 0x1E/255.0, green: 0x10/255.0, blue: 0x35/255.0)
    // Pressed / deeper violet (#8B5CF6)
    static let brandEmberGlow    = Color(red: 0x8B/255.0, green: 0x5C/255.0, blue: 0xF6/255.0)

    // Surfaces
    static let warmSurface       = Color(red: 0xF5/255.0, green: 0xF3/255.0, blue: 0xFF/255.0) // light purple canvas
    static let warmSurfaceDark   = Color(red: 0x0D/255.0, green: 0x07/255.0, blue: 0x1A/255.0) // Very deep purple canvas

    // Categorical provider colors (distinct hues, good contrast on dark)
    static let categoricalClaude = Color(red: 0xDA/255.0, green: 0x7E/255.0, blue: 0x56/255.0) // Anthropic warm
    static let categoricalCursor = Color(red: 0x3F/255.0, green: 0x6B/255.0, blue: 0x8C/255.0) // Cursor blue
    static let categoricalCodex  = Color(red: 0x4A/255.0, green: 0x7D/255.0, blue: 0x5C/255.0) // Codex green

    // One-shot success rate indicators
    static let oneShotGood  = Color(red: 0x86/255.0, green: 0xEF/255.0, blue: 0xAC/255.0) // success green
    static let oneShotMid   = Color(red: 0xC4/255.0, green: 0xB5/255.0, blue: 0xFD/255.0) // mid lavender
    static let oneShotLow   = Color(red: 0xF8/255.0, green: 0x71/255.0, blue: 0x71/255.0) // error red

    // Semantic colors — tuned for QM deep purple surfaces.
    static let semanticDanger  = Color(red: 0xDC/255.0, green: 0x26/255.0, blue: 0x26/255.0) // clear red
    static let semanticWarning = Color(red: 0xE8/255.0, green: 0xB4/255.0, blue: 0xFE/255.0) // soft purple warning
    static let semanticSuccess = Color(red: 0x16/255.0, green: 0xA3/255.0, blue: 0x4A/255.0) // confident green
}

extension Font {
    /// SF Mono for currency values -- developer-tool identity.
    static func codeMono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Modifier for accent-background buttons that need dark text.
extension View {
    func goldButton() -> some View {
        self
            .buttonStyle(.borderedProminent)
            .tint(Theme.brandAccent)
            .foregroundStyle(Theme.brandPurpleDark)
            .noFocusRing()
    }

    /// Menu bar popovers are pointer-first surfaces. macOS's blue keyboard focus ring
    /// is visually loud against the Watcher dark UI, so controls that remain native
    /// buttons/menus opt out of focus painting here.
    func noFocusRing() -> some View {
        self
            .focusable(false)
            .focusEffectDisabled()
    }
}
