import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Onyx theme
//
// Black / white / scarlet palette from the RipperMoonKit redesign. Subtle Apple
// Tahoe cues: large radii, layered hairlines, soft scarlet accent. Every color
// is appearance-dynamic, so the app tracks light/dark automatically.

enum Onyx {
    private static func dyn(
        light: (CGFloat, CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat, CGFloat)
    ) -> Color {
        let nsColor = NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: c.3)
        }
        return Color(nsColor: nsColor)
    }

    static let bg        = dyn(light: (0.984, 0.984, 0.984, 1), dark: (0.102, 0.102, 0.102, 1))
    static let bgDeep    = dyn(light: (0.937, 0.937, 0.937, 1), dark: (0.063, 0.063, 0.063, 1))
    static let surface   = dyn(light: (1.000, 1.000, 1.000, 1), dark: (0.149, 0.149, 0.149, 1))
    static let surface2  = dyn(light: (0.949, 0.949, 0.949, 1), dark: (0.205, 0.205, 0.205, 1))
    static let text      = dyn(light: (0.110, 0.110, 0.110, 1), dark: (0.969, 0.969, 0.969, 1))
    static let textDim   = dyn(light: (0.345, 0.345, 0.345, 1), dark: (0.660, 0.660, 0.660, 1))
    static let textMute  = dyn(light: (0.560, 0.560, 0.560, 1), dark: (0.480, 0.480, 0.480, 1))
    static let hairline  = dyn(light: (0, 0, 0, 0.08), dark: (1, 1, 1, 0.08))
    static let hairline2 = dyn(light: (0, 0, 0, 0.14), dark: (1, 1, 1, 0.14))
    static let accent    = dyn(light: (0.710, 0.122, 0.090, 1), dark: (0.878, 0.184, 0.137, 1))
    static let accent2   = dyn(light: (0.560, 0.110, 0.080, 1), dark: (0.690, 0.150, 0.110, 1))
    static let accentInk = dyn(light: (0.99, 0.99, 0.99, 1), dark: (0.99, 0.99, 0.99, 1))
    static let good      = dyn(light: (0.180, 0.490, 0.318, 1), dark: (0.471, 0.706, 0.553, 1))
    static let warn      = dyn(light: (0.620, 0.450, 0.160, 1), dark: (0.820, 0.660, 0.400, 1))
    static let glow      = dyn(light: (0.710, 0.122, 0.090, 0.45), dark: (0.878, 0.184, 0.137, 0.5))

    static let cardRadius: CGFloat = 16
    static let tileRadius: CGFloat = 12
}

/// Deterministic per-game seed used to vary the placeholder cover art.
func coverSeed(_ name: String) -> Int {
    name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
}
