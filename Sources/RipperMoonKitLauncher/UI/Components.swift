import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Flow layout (wrapping button rows)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? max(x - spacing, 0) : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Primitives

struct BrandMark: View {
    var size: CGFloat = 26
    var glow: Bool = false

    /// Loaded once from the package resource bundle. `Image(_:bundle:)` does not
    /// reliably resolve a loose PNG in a flat SPM resource bundle on macOS, so the
    /// logo is loaded by URL instead.
    private static let logo = AppResource.image(named: "rippermoonlogo")

    var body: some View {
        Group {
            if let logo = BrandMark.logo {
                Image(nsImage: logo).resizable().scaledToFit()
            } else {
                Image(systemName: "moon.stars.fill")
                    .resizable().scaledToFit()
                    .foregroundStyle(Onyx.accent)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: glow ? Onyx.glow.opacity(0.5) : .clear, radius: glow ? 7 : 0)
    }
}

struct PulseDot: View {
    var color: Color
    var size: CGFloat = 7
    @State private var animating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .scaleEffect(animating ? 2.6 : 1)
                .opacity(animating ? 0 : 0.8)
            Circle().fill(color)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                animating = true
            }
        }
    }
}

struct RMKButton: View {
    enum Kind { case primary, ghost, soft, danger }

    var kind: Kind = .ghost
    var icon: String? = nil
    var title: String
    var small: Bool = false
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: small ? 10 : 11, weight: .semibold)) }
                Text(title)
            }
            .font(.system(size: small ? 11.5 : 12.5, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, small ? 10 : 13)
            .padding(.vertical, small ? 5 : 7)
            .background(background, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous).strokeBorder(border, lineWidth: 0.75)
            }
            .shadow(color: kind == .primary ? Onyx.glow.opacity(0.35) : .clear,
                    radius: kind == .primary ? 8 : 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return Onyx.accentInk
        case .ghost:   return Onyx.text
        case .soft:    return Onyx.textDim
        case .danger:  return Onyx.accent
        }
    }
    private var background: Color {
        switch kind {
        case .primary: return Onyx.accent
        case .ghost:   return Onyx.surface2
        case .soft, .danger: return .clear
        }
    }
    private var border: Color {
        switch kind {
        case .primary: return .clear
        case .ghost:   return Onyx.hairline2
        case .soft:    return Onyx.hairline
        case .danger:  return Onyx.hairline
        }
    }
}

struct RMKChip: View {
    var title: String
    var active: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(active ? Onyx.accentInk : Onyx.textDim)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(active ? Onyx.accent : .clear, in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(active ? .clear : Onyx.hairline, lineWidth: 0.75)
                }
        }
        .buttonStyle(.plain)
    }
}

struct Card<Content: View>: View {
    let title: String
    let icon: String
    var trailing: AnyView? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Onyx.accent)
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Onyx.text)
                Spacer(minLength: 8)
                if let trailing { trailing }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Onyx.surface, in: RoundedRectangle(cornerRadius: Onyx.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Onyx.cardRadius, style: .continuous)
                .strokeBorder(Onyx.hairline, lineWidth: 0.75)
        }
    }
}

struct SectionHelpIcon: View {
    let text: String

    var body: some View {
        Image(systemName: "questionmark.circle")
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Onyx.textMute)
            .help(text)
    }
}

struct CollapsibleCard<Content: View>: View {
    let title: String
    let icon: String
    let storageKey: String
    var defaultCollapsed = false
    var help: String = ""
    var trailing: AnyView? = nil
    @AppStorage private var collapsed: Bool
    @ViewBuilder let content: Content

    init(title: String,
         icon: String,
         storageKey: String,
         defaultCollapsed: Bool = false,
         help: String = "",
         trailing: AnyView? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.storageKey = storageKey
        self.defaultCollapsed = defaultCollapsed
        self.help = help
        self.trailing = trailing
        self.content = content()
        _collapsed = AppStorage(wrappedValue: defaultCollapsed, storageKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: collapsed ? 0 : 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Onyx.accent)
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Onyx.text)
                Spacer(minLength: 8)
                if !help.isEmpty {
                    SectionHelpIcon(text: help)
                }
                if let trailing { trailing }
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        collapsed.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Onyx.textMute)
                        .rotationEffect(.degrees(collapsed ? -90 : 0))
                        .frame(width: 24, height: 24)
                        .background(Onyx.surface2, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Onyx.hairline2, lineWidth: 0.75)
                        }
                }
                .buttonStyle(.plain)
                .help(collapsed ? "Expand \(title)" : "Collapse \(title)")
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.16)) {
                    collapsed.toggle()
                }
            }

            if !collapsed {
                content
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Onyx.surface, in: RoundedRectangle(cornerRadius: Onyx.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Onyx.cardRadius, style: .continuous)
                .strokeBorder(Onyx.hairline, lineWidth: 0.75)
        }
    }
}

struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Onyx.textDim)
            .frame(width: 104, alignment: .leading)
    }
}

struct OnyxField: View {
    @Binding var text: String
    var placeholder: String = ""
    var mono: Bool = false
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(mono ? .system(size: 12, design: .monospaced) : .system(size: 12.5))
                .foregroundStyle(Onyx.text)
            if let trailing { trailing }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Onyx.bgDeep, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Onyx.hairline, lineWidth: 0.75)
        }
    }
}

struct FieldRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content
    var body: some View {
        HStack(spacing: 12) {
            FieldLabel(label)
            content
        }
    }
}

struct IconButton: View {
    let systemImage: String
    var help: String = ""
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Onyx.textDim)
                .frame(width: 28, height: 28)
                .background(Onyx.surface2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Onyx.hairline, lineWidth: 0.75)
                }
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct PathEditor: View {
    let title: String
    @Binding var path: String
    let action: () -> Void
    var body: some View {
        FieldRow(label: title) {
            OnyxField(text: $path, mono: true)
            IconButton(systemImage: "folder", help: "Choose \(title)", action: action)
        }
    }
}

struct ValidationRow: View {
    let title: String
    let isOK: Bool
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isOK ? Onyx.good : Onyx.accent)
            Text(title)
                .font(.system(size: 12.5))
                .foregroundStyle(Onyx.text)
            Spacer()
            Text(isOK ? "Found" : "Missing")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Onyx.textMute)
                .textCase(.uppercase)
        }
    }
}

/// Cover art — uses the profile icon when present, else a seeded scarlet-washed
/// gradient with the title initials.
struct CoverArt: View {
    var iconPath: String?
    var label: String
    var seed: Int
    var corner: CGFloat = 12
    var showLabel: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image = loadedImage {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Color(white: 0.27), Color(white: 0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    RadialGradient(
                        colors: [Onyx.accent.opacity(0.42), .clear],
                        center: UnitPoint(x: washX, y: 0.28),
                        startRadius: 1, endRadius: max(geo.size.width, geo.size.height)
                    )
                    if showLabel && min(geo.size.width, geo.size.height) > 34 {
                        Text(initials)
                            .font(.system(size: min(13, geo.size.height * 0.2),
                                          weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    private var loadedImage: NSImage? {
        guard let path = iconPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else { return nil }
        return NSImage(contentsOfFile: path)
    }
    private var washX: CGFloat { CGFloat((seed * 71) % 100) / 100 }
    private var initials: String {
        let words = label.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}

struct Terminal: View {
    let title: String
    let body0: String
    var live: Bool = false

    init(title: String, text: String, live: Bool = false) {
        self.title = title
        self.body0 = text
        self.live = live
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach([Color(red: 1, green: 0.37, blue: 0.34),
                             Color(red: 1, green: 0.74, blue: 0.18),
                             Color(red: 0.16, green: 0.78, blue: 0.25)], id: \.self) { c in
                        Circle().fill(c).frame(width: 10, height: 10)
                    }
                }
                Text(title)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Onyx.textMute)
                Spacer()
                if live {
                    HStack(spacing: 5) {
                        PulseDot(color: Onyx.good, size: 6)
                        Text("LIVE").font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Onyx.good)
                    }
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(Onyx.surface)
            .overlay(alignment: .bottom) { Rectangle().fill(Onyx.hairline).frame(height: 1) }

            ScrollView {
                Text(body0.isEmpty ? "No activity yet." : body0)
                    .font(.system(size: 11.2, design: .monospaced))
                    .foregroundStyle(body0.isEmpty ? Onyx.textMute : Onyx.textDim)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(minHeight: 56)
        }
        .background(Onyx.bgDeep)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Onyx.hairline2, lineWidth: 0.75)
        }
    }
}

// MARK: - Root
