import SwiftUI

/// Design tokens — Quantum Memory palette, tuned for Liquid Glass surfaces.
///
/// macOS 26 (Tahoe) Liquid Glass works best when the background it floats over has
/// real chromatic depth — so the popover stack is:
///   1. `glassBaseGradient` (deep violet → near-black) painted edge-to-edge
///   2. `glassAccentHalo` (radial lavender bleed) on top of the gradient
///   3. `.glassEffect(.regular.tint(brandGlassTint))` on the popover surface
///   4. Section content drawn at full opacity on top
///
/// Accents stay in the existing QM lavender/violet family so glass tints read on-brand.
enum Theme {
    // MARK: - Brand accents (unchanged — read-through to glass surfaces)

    /// QM Lavender (#A78BFA) — primary accent, header wordmark, value figure.
    static let brandAccent       = Color(red: 0xA7/255.0, green: 0x8B/255.0, blue: 0xFA/255.0)
    /// Hover / lighter lavender (#C4B5FD).
    static let brandAccentDark   = Color(red: 0xC4/255.0, green: 0xB5/255.0, blue: 0xFD/255.0)
    /// Mid purple for depth/glow (#7C3AED).
    static let brandEmberDeep    = Color(red: 0x7C/255.0, green: 0x3A/255.0, blue: 0xED/255.0)
    /// Dark purple for text on light purple/glass-tinted backgrounds (#1E1035).
    static let brandPurpleDark   = Color(red: 0x1E/255.0, green: 0x10/255.0, blue: 0x35/255.0)
    /// Pressed / deeper violet (#8B5CF6).
    static let brandEmberGlow    = Color(red: 0x8B/255.0, green: 0x5C/255.0, blue: 0xF6/255.0)

    // MARK: - Surfaces (legacy — kept for non-glass fallbacks)

    static let warmSurface       = Color(red: 0xF5/255.0, green: 0xF3/255.0, blue: 0xFF/255.0)
    static let warmSurfaceDark   = Color(red: 0x0D/255.0, green: 0x07/255.0, blue: 0x1A/255.0)

    // MARK: - Glass surface tokens (macOS 26 Liquid Glass)

    /// Painted edge-to-edge behind the glass pane. Provides the chromatic
    /// depth that makes Liquid Glass look like glass and not flat material.
    static let glassBaseGradient = LinearGradient(
        colors: [
            Color(red: 0x14/255.0, green: 0x08/255.0, blue: 0x28/255.0),  // top-left: aubergine
            Color(red: 0x07/255.0, green: 0x03/255.0, blue: 0x14/255.0),  // mid: near-black violet
            Color(red: 0x1D/255.0, green: 0x0E/255.0, blue: 0x3A/255.0)   // bottom-right: deep indigo
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// A soft accent halo painted behind the glass — lets the lavender warmth
    /// bleed through instead of washing flat.
    static let glassAccentHalo = RadialGradient(
        colors: [
            Color(red: 0xA7/255.0, green: 0x8B/255.0, blue: 0xFA/255.0).opacity(0.22),
            Color.clear
        ],
        center: .topLeading,
        startRadius: 20,
        endRadius: 320
    )

    /// Soft tint applied INSIDE the popover glass pane — gives it the QM lilac
    /// undertone without making it opaque.
    static let brandGlassTint = Color(red: 0x9C/255.0, green: 0x7A/255.0, blue: 0xFA/255.0).opacity(0.18)

    /// Darker, more saturated tint for floating chips (segmented active state, account pill).
    static let brandGlassChip = Color(red: 0x8B/255.0, green: 0x5C/255.0, blue: 0xF6/255.0).opacity(0.55)

    /// Top-edge highlight that sells the "glass" specular look.
    static let glassHighlight    = Color.white.opacity(0.10)
    /// Subtle interior border for glass surfaces.
    static let glassBorder       = Color.white.opacity(0.08)

    // MARK: - Categorical / semantic (unchanged)

    static let categoricalClaude = Color(red: 0xDA/255.0, green: 0x7E/255.0, blue: 0x56/255.0)
    static let categoricalCursor = Color(red: 0x3F/255.0, green: 0x6B/255.0, blue: 0x8C/255.0)
    static let categoricalCodex  = Color(red: 0x4A/255.0, green: 0x7D/255.0, blue: 0x5C/255.0)

    static let oneShotGood  = Color(red: 0x86/255.0, green: 0xEF/255.0, blue: 0xAC/255.0)
    static let oneShotMid   = Color(red: 0xC4/255.0, green: 0xB5/255.0, blue: 0xFD/255.0)
    static let oneShotLow   = Color(red: 0xF8/255.0, green: 0x71/255.0, blue: 0x71/255.0)

    static let semanticDanger  = Color(red: 0xDC/255.0, green: 0x26/255.0, blue: 0x26/255.0)
    static let semanticWarning = Color(red: 0xE8/255.0, green: 0xB4/255.0, blue: 0xFE/255.0)
    static let semanticSuccess = Color(red: 0x16/255.0, green: 0xA3/255.0, blue: 0x4A/255.0)
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

/// The canonical Quantum Memory glass canvas — paint behind any Liquid Glass surface.
/// Stacks the gradient + halo so when `.glassEffect()` is applied above, it has
/// chromatic depth to refract instead of flat black.
struct QMGlassCanvas: View {
    var body: some View {
        ZStack {
            Theme.glassBaseGradient
            Theme.glassAccentHalo
        }
        .ignoresSafeArea()
    }
}

/// Reusable glass pill modifier for floating chips / segmented controls / account pills.
extension View {
    /// Wrap the view in a Liquid Glass capsule. `tinted` applies the QM lavender chip tint
    /// for active/selected states; otherwise stays clear so it just refracts the canvas.
    @ViewBuilder
    func qmGlassPill(cornerRadius: CGFloat = 8, tinted: Bool = false) -> some View {
        if tinted {
            self.glassEffect(
                .regular.tint(Theme.brandGlassChip),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self.glassEffect(
                .regular,
                in: .rect(cornerRadius: cornerRadius)
            )
        }
    }
}
