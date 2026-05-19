import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - App

@main
struct RipperMoonKitLauncherApp: App {
    @StateObject private var model = LauncherModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1080, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}

private enum SidebarSelection: Hashable {
    case library
    case profile(UUID)
    case backups
    case settings
}

private let rmkAppVersion: String =
    (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"

private let rmkRepositoryURL = "https://github.com/MoonTheRipper/RipperMoonKit.git"

private struct UpdateNotice: Identifiable, Equatable {
    let version: String
    let url: URL

    var id: String { version }
}

private struct GitHubReleaseInfo: Decodable {
    let tagName: String
    let htmlURL: URL?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

private struct SetupCheck: Identifiable, Hashable {
    let id: String
    let title: String
    let explanation: String
    let detail: String
    let isOK: Bool
    let isOptional: Bool
}

private enum AppResource {
    private static let resourceBundleName = "RipperMoonKit_RipperMoonKitLauncher.bundle"

    static func image(named name: String, extension ext: String = "png") -> NSImage? {
        guard let url = url(forResource: name, withExtension: ext) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    static func url(forResource name: String, withExtension ext: String) -> URL? {
        let fileName = "\(name).\(ext)"
        let candidates: [URL?] = [
            Bundle.main.resourceURL?
                .appendingPathComponent(resourceBundleName)
                .appendingPathComponent(fileName),
            Bundle.main.resourceURL?
                .appendingPathComponent(fileName),
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent(resourceBundleName)
                .appendingPathComponent(fileName),
            Bundle.main.bundleURL
                .appendingPathComponent(resourceBundleName)
                .appendingPathComponent(fileName)
        ]

        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}

// MARK: - Onyx theme
//
// Black / white / scarlet palette from the RipperMoonKit redesign. Subtle Apple
// Tahoe cues: large radii, layered hairlines, soft scarlet accent. Every color
// is appearance-dynamic, so the app tracks light/dark automatically.

private enum Onyx {
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
private func coverSeed(_ name: String) -> Int {
    name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
}

// MARK: - Flow layout (wrapping button rows)

private struct FlowLayout: Layout {
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

private struct BrandMark: View {
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

private struct PulseDot: View {
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

private struct RMKButton: View {
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

private struct RMKChip: View {
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

private struct Card<Content: View>: View {
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

private struct SectionHelpIcon: View {
    let text: String

    var body: some View {
        Image(systemName: "questionmark.circle")
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Onyx.textMute)
            .help(text)
    }
}

private struct CollapsibleCard<Content: View>: View {
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

private struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Onyx.textDim)
            .frame(width: 104, alignment: .leading)
    }
}

private struct OnyxField: View {
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

private struct FieldRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content
    var body: some View {
        HStack(spacing: 12) {
            FieldLabel(label)
            content
        }
    }
}

private struct IconButton: View {
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

private struct PathEditor: View {
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

private struct ValidationRow: View {
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
private struct CoverArt: View {
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

private struct Terminal: View {
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

private struct ContentView: View {
    @EnvironmentObject private var model: LauncherModel
    @State private var selection: SidebarSelection = .library
    @State private var sidebarOpen = true
    @State private var darkOverride: Bool? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Onyx.bg.ignoresSafeArea()

            Circle()
                .fill(Onyx.accent)
                .frame(width: 460, height: 460)
                .blur(radius: 130)
                .opacity(0.10)
                .offset(x: 150, y: -260)
                .allowsHitTesting(false)

            HStack(spacing: 0) {
                if sidebarOpen {
                    RMKSidebar(selection: $selection, darkOverride: $darkOverride)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                VStack(spacing: 0) {
                    RMKTopbar(selection: $selection, sidebarOpen: $sidebarOpen)
                    if model.config.needsSetupGuide && !model.showSetupGuide {
                        SetupBanner()
                    }
                    ScrollView { screen.padding(.bottom, 4) }
                }
            }
        }
        .preferredColorScheme(darkOverride.map { $0 ? .dark : .light })
        .onAppear { model.reload() }
        .task {
            await model.checkForAvailableUpdate()
            while !Task.isCancelled {
                await model.refreshLiveStatus()
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
        .sheet(isPresented: $model.showSetupGuide) {
            SetupGuideView()
                .environmentObject(model)
                .frame(width: 640)
                .interactiveDismissDisabled(true)
        }
        .onChange(of: model.pendingSelection) { _, newValue in
            if let newValue {
                selection = newValue
                model.pendingSelection = nil
            }
        }
        .animation(.easeInOut(duration: 0.22), value: sidebarOpen)
    }

    @ViewBuilder private var screen: some View {
        switch selection {
        case .library:
            LibraryScreen(selection: $selection)
        case .backups:
            BackupsScreen()
        case .settings:
            SettingsScreen()
        case .profile(let id):
            if let binding = model.profileBinding(id: id) {
                GameDetailScreen(profile: binding, selection: $selection)
            } else {
                EmptyStateView(title: "Profile Missing",
                               detail: "Choose another app or add a new one.")
                    .padding(24)
            }
        }
    }
}

// MARK: - Sidebar

private struct RMKSidebar: View {
    @EnvironmentObject private var model: LauncherModel
    @Binding var selection: SidebarSelection
    @Binding var darkOverride: Bool?
    @Environment(\.colorScheme) private var scheme
    @State private var editingPins = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 30)

            HStack(spacing: 10) {
                BrandMark(size: 51, glow: true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("RipperMoonKit")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Onyx.text)
                    Text("v\(rmkAppVersion) · Onyx")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Onyx.textMute)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            sectionLabel("Library")
            navItem(.library, "Games & Apps", "square.grid.2x2.fill")

            sectionLabel("Toolkit")
            navItem(.backups, "Backups", "clock.arrow.circlepath")
            navItem(.settings, "Settings", "gearshape.fill")
            UpdateNoticeBanner(selection: $selection)

            if model.profiles.isEmpty {
                Spacer(minLength: 12)
            } else {
                pinnedHeader
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(model.pinnedProfiles) { profile in
                            pinnedRow(profile)
                        }
                        if model.pinnedProfiles.isEmpty && !editingPins {
                            emptyPinHint
                        }
                        if editingPins {
                            addPinControl
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: .infinity)
                .scrollIndicators(.hidden)
            }

            HelpButton()
            KofiSupport()
            FeedbackButton(selection: selection)
            footer
        }
        .frame(width: 224)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Onyx.hairline).frame(width: 1)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(Onyx.textMute)
            .textCase(.uppercase)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }

    private func navItem(_ target: SidebarSelection, _ label: String, _ icon: String) -> some View {
        let active = selection == target
        return Button {
            selection = target
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(active ? Onyx.accentInk : Onyx.accent)
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(active ? Onyx.accentInk : Onyx.text)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(active ? Onyx.accent : .clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }

    private var pinnedHeader: some View {
        HStack {
            Text("Pinned")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Onyx.textMute)
                .textCase(.uppercase)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { editingPins.toggle() }
            } label: {
                Text(editingPins ? "Done" : "Edit")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(editingPins ? Onyx.accent : Onyx.textMute)
            }
            .buttonStyle(.plain)
            .help(editingPins ? "Finish editing pins" : "Add or remove pinned games")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private func pinnedRow(_ profile: GameProfile) -> some View {
        let active = selection == .profile(profile.id) && !editingPins
        return HStack(spacing: 9) {
            CoverArt(iconPath: profile.iconPath, label: profile.name,
                     seed: coverSeed(profile.name), corner: 5, showLabel: false)
                .frame(width: 20, height: 20)
            Text(profile.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Onyx.text)
                .lineLimit(1)
            Spacer(minLength: 0)
            if editingPins {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { model.unpinProfile(profile.id) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Onyx.accent)
                }
                .buttonStyle(.plain)
                .help("Unpin \(profile.name)")
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(active ? Onyx.surface2 : .clear,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if !editingPins { selection = .profile(profile.id) }
        }
    }

    private var emptyPinHint: some View {
        Text("Tap Edit to pin games here.")
            .font(.system(size: 10.5))
            .foregroundStyle(Onyx.textMute)
            .padding(.horizontal, 19)
            .padding(.vertical, 6)
    }

    @ViewBuilder private var addPinControl: some View {
        if model.unpinnedProfiles.isEmpty {
            Text("All games pinned.")
                .font(.system(size: 10.5))
                .foregroundStyle(Onyx.textMute)
                .padding(.horizontal, 19)
                .padding(.vertical, 6)
        } else {
            Menu {
                ForEach(model.unpinnedProfiles) { profile in
                    Button(profile.name) {
                        withAnimation(.easeInOut(duration: 0.15)) { model.pinProfile(profile.id) }
                    }
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(Onyx.accent)
                        .frame(width: 20)
                    Text("Add game")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Onyx.accent)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .padding(.horizontal, 8)
            .padding(.top, 2)
        }
    }

    private var footer: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "moonphase.waxing.gibbous.inverse")
                    .font(.system(size: 14))
                    .foregroundStyle(Onyx.accent)
                Text("Waxing Gibbous")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Onyx.textDim)
                Spacer()
            }
            Rectangle().fill(Onyx.hairline).frame(height: 1)
            HStack(spacing: 6) {
                Text("Appearance")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.3)
                    .foregroundStyle(Onyx.textMute)
                    .textCase(.uppercase)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { scheme == .dark },
                    set: { darkOverride = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .tint(Onyx.accent)
            }
        }
        .padding(12)
        .background(Onyx.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Onyx.hairline, lineWidth: 0.75)
        }
        .padding(10)
    }
}

private struct UpdateNoticeBanner: View {
    @EnvironmentObject private var model: LauncherModel
    @Binding var selection: SidebarSelection

    var body: some View {
        if let notice = model.updateNotice {
            Button {
                selection = .settings
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Onyx.accent)
                        Text("Update Available")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Onyx.text)
                        Spacer(minLength: 0)
                    }
                    Text("\(notice.version) is on GitHub. Go to Settings > Maintenance > Update From GitHub.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Onyx.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Onyx.surface2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Onyx.accent.opacity(0.35), lineWidth: 0.9)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .help("Open Settings to update RipperMoonKit from GitHub.")
        }
    }
}

// MARK: - Topbar

/// Sidebar support prompt — a plain one-liner and a bordered Ko-fi button.
private struct KofiSupport: View {
    private static let logo = AppResource.image(named: "kofi_logo")

    var body: some View {
        VStack(spacing: 9) {
            Text("Not a big ask — but $5 helps the dev keep this app alive.")
                .font(.system(size: 10.5))
                .foregroundStyle(Onyx.textMute)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if let url = URL(string: "https://ko-fi.com/moontheripper") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Group {
                    if let logo = KofiSupport.logo {
                        Image(nsImage: logo).resizable().scaledToFit()
                    } else {
                        Text("Support on Ko-fi")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                }
                .frame(height: 13)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 2, y: 0.5)
            }
            .buttonStyle(.plain)
            .help("Support the developer on Ko-fi")
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 2)
    }
}

/// Creates a structured tester report without embedding GitHub credentials in the app.
private struct FeedbackButton: View {
    @EnvironmentObject private var model: LauncherModel
    let selection: SidebarSelection

    var body: some View {
        Button {
            model.reportTestResult(for: selectedProfile)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Onyx.accent)
                Text("Report Test Result")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Onyx.text)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Onyx.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Onyx.hairline, lineWidth: 0.75)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .help("Copy a structured tester report and open a prefilled GitHub issue.")
    }

    private var selectedProfile: GameProfile? {
        guard case let .profile(id) = selection else { return nil }
        return model.profiles.first { $0.id == id }
    }
}

/// Sidebar entry that opens the bundled how-to documentation.
private struct HelpButton: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        Button {
            model.openHelpDocs()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Onyx.accent)
                Text("Help & Docs")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Onyx.text)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Onyx.textMute)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Onyx.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Onyx.hairline, lineWidth: 0.75)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .help("Open the RipperMoonKit guide — setup, adding games, and launching.")
    }
}

private struct RMKTopbar: View {
    @EnvironmentObject private var model: LauncherModel
    @Binding var selection: SidebarSelection
    @Binding var sidebarOpen: Bool

    var body: some View {
        HStack(spacing: 14) {
            Color.clear.frame(width: sidebarOpen ? 0 : 64, height: 1)

            Button {
                sidebarOpen.toggle()
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13))
                    .foregroundStyle(Onyx.textDim)
                    .frame(width: 28, height: 28)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Onyx.hairline, lineWidth: 0.75)
                    }
            }
            .buttonStyle(.plain)

            icon

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 7) {
                    if breadcrumb != nil {
                        Text(breadcrumb!)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Onyx.textMute)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Onyx.textMute)
                    }
                    Text(title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Onyx.text)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Onyx.textMute)
                        .lineLimit(1)
                }
            }

            Spacer()

            RMKButton(kind: .ghost, icon: "arrow.clockwise", title: "Refresh", small: true) {
                model.reload()
            }
            Button {
                let profile = model.addProfile()
                selection = .profile(profile.id)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Onyx.accentInk)
                    .frame(width: 30, height: 30)
                    .background(Onyx.accent, in: Circle())
                    .shadow(color: Onyx.glow.opacity(0.4), radius: 7, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(minHeight: 58)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Rectangle().fill(Onyx.hairline).frame(height: 1) }
    }

    private var currentProfile: GameProfile? {
        guard case .profile(let id) = selection else { return nil }
        return model.profiles.first { $0.id == id }
    }

    @ViewBuilder private var icon: some View {
        if let profile = currentProfile {
            CoverArt(iconPath: profile.iconPath, label: profile.name,
                     seed: coverSeed(profile.name), corner: 7, showLabel: false)
                .frame(width: 26, height: 26)
        } else {
            BrandMark(size: 24, glow: true)
        }
    }

    private var breadcrumb: String? {
        if case .profile = selection { return "Library" }
        return nil
    }

    private var title: String {
        switch selection {
        case .library:  return "RipperMoonKit"
        case .backups:  return "Backups"
        case .settings: return "Settings"
        case .profile:  return currentProfile?.name ?? "Profile"
        }
    }

    private var subtitle: String? {
        switch selection {
        case .settings: return model.config.configPath
        default:        return "Macs can't game? Cute. Reap anyway."
        }
    }
}

// MARK: - Library

/// Primary banner button that crossfades between Launch and Stop with the
/// profile's live state — shared by the Library banner and the in-profile hero.
private struct LaunchStopButton: View {
    var isLive: Bool
    var launchTitle: String = "Launch"
    var onLaunch: () -> Void
    var onStop: () -> Void

    var body: some View {
        ZStack {
            if isLive {
                RMKButton(kind: .primary, icon: "stop.fill", title: "Stop", action: onStop)
                    .transition(.opacity)
            } else {
                RMKButton(kind: .primary, icon: "power", title: launchTitle, action: onLaunch)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isLive)
    }
}

private enum LibraryFilter: String, CaseIterable {
    case all = "All", modded = "Modded", steam = "Steam", native = "Native"
}

private struct LibraryScreen: View {
    @EnvironmentObject private var model: LauncherModel
    @Binding var selection: SidebarSelection
    @State private var filter: LibraryFilter = .all
    @State private var query = ""
    @State private var featuredIndex = Int.random(in: 0 ..< 999)

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let featured {
                heroBanner(featured.profile, isLive: featured.live)
                    .id(featured.profile.id)
                    .transition(.opacity)
            }
            filterRow
            grid
            if !query.isEmpty && visible.isEmpty {
                emptyState
            }
        }
        .padding(EdgeInsets(top: 20, leading: 24, bottom: 40, trailing: 24))
        .task {
            // Auto-shuffle the spotlight every 5.5s while no game is running.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_500_000_000)
                if featured?.live == false {
                    withAnimation(.easeInOut(duration: 0.4)) { featuredIndex += 1 }
                }
            }
        }
    }

    /// Real games — everything except the Steam client.
    private var realGames: [GameProfile] {
        model.profiles.filter { !$0.isSteamApp }
    }

    /// The banner pick: a running game takes over; otherwise the shuffled spotlight.
    private var featured: (profile: GameProfile, live: Bool)? {
        if let live = realGames.first(where: { model.liveProfileIDs.contains($0.id) }) {
            return (live, true)
        }
        guard !realGames.isEmpty else { return nil }
        let index = ((featuredIndex % realGames.count) + realGames.count) % realGames.count
        return (realGames[index], false)
    }

    private func shuffleFeatured() {
        withAnimation(.easeInOut(duration: 0.2)) { featuredIndex += 1 }
    }

    private var visible: [GameProfile] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = model.profiles.filter { p in
            let matchesQuery = q.isEmpty
                || p.name.lowercased().contains(q)
                || p.executable.lowercased().contains(q)
            let matchesFilter: Bool
            switch filter {
            case .all:    matchesFilter = true
            case .modded: matchesFilter = p.supportsModEngine
            case .steam:  matchesFilter = p.requiresSteam || p.isSteamApp || p.isSteamLibraryGame
            case .native: matchesFilter = !p.requiresSteam && !p.isSteamApp && !p.isSteamLibraryGame
            }
            return matchesQuery && matchesFilter
        }
        // The Steam client always holds the first grid slot.
        return filtered.filter { $0.isSteamApp } + filtered.filter { !$0.isSteamApp }
    }

    private func heroBanner(_ profile: GameProfile, isLive: Bool) -> some View {
        ZStack(alignment: .leading) {
            CoverArt(iconPath: profile.iconPath, label: profile.name,
                     seed: coverSeed(profile.name), corner: 22, showLabel: false)
            LinearGradient(
                colors: [Onyx.bgDeep.opacity(0.95), Onyx.bgDeep.opacity(0.2), .clear],
                startPoint: .leading, endPoint: .trailing
            )
            VStack(alignment: .leading, spacing: 9) {
                Text(isLive ? "Now Playing" : "Spotlight")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(isLive ? Onyx.good : Onyx.accent)
                    .textCase(.uppercase)
                Text(profile.name)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Onyx.text)
                Text(heroSubtitle(profile))
                    .font(.system(size: 12))
                    .foregroundStyle(Onyx.textDim)
                HStack(spacing: 8) {
                    LaunchStopButton(
                        isLive: isLive,
                        launchTitle: "Launch",
                        onLaunch: { model.launch(profile) },
                        onStop: { model.closeGame(profile) }
                    )
                    RMKButton(kind: .ghost, icon: "chevron.right", title: "Open") {
                        selection = .profile(profile.id)
                    }
                }
                .padding(.top, 4)
            }
            .padding(22)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isLive ? Onyx.good.opacity(0.55) : Onyx.hairline,
                              lineWidth: isLive ? 1 : 0.75)
        }
        .overlay(alignment: .trailing) {
            BrandMark(size: 120).opacity(0.16).padding(.trailing, 28)
        }
        .overlay(alignment: .topTrailing) {
            heroCorner(isLive: isLive)
        }
        .contentShape(Rectangle())
        .onTapGesture { selection = .profile(profile.id) }
    }

    /// Idle banner shows a manual shuffle control; a live banner has none
    /// (the green border + "Now Playing" label carry the live state).
    @ViewBuilder private func heroCorner(isLive: Bool) -> some View {
        if !isLive {
            Button { shuffleFeatured() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Onyx.text)
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay { Circle().strokeBorder(Onyx.hairline2, lineWidth: 0.75) }
            }
            .buttonStyle(.plain)
            .help("Shuffle the spotlight")
            .padding(14)
        }
    }

    private func heroSubtitle(_ p: GameProfile) -> String {
        if p.isSteamApp { return "Steam client" }
        if p.supportsModEngine { return "Modded · ModEngine 2 ready" }
        if p.requiresSteam { return "Uses Steam · \(p.prefix)" }
        return "\(p.prefix) · \(p.winver)"
    }

    private var filterRow: some View {
        HStack(spacing: 14) {
            Text("Library")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Onyx.text)
            Text(query.isEmpty
                 ? "\(model.profiles.count) games & apps"
                 : "\(visible.count) of \(model.profiles.count)")
                .font(.system(size: 11.5))
                .foregroundStyle(Onyx.textMute)
            Spacer()
            searchField
            HStack(spacing: 6) {
                ForEach(LibraryFilter.allCases, id: \.self) { f in
                    RMKChip(title: f.rawValue, active: filter == f) { filter = f }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Onyx.textDim)
            TextField("Search games", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Onyx.text)
                .frame(width: 130)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Onyx.textMute)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Onyx.surface2, in: Capsule(style: .continuous))
        .overlay { Capsule(style: .continuous).strokeBorder(Onyx.hairline2, lineWidth: 0.75) }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(visible) { profile in
                LibraryTile(
                    profile: profile,
                    isLive: model.liveProfileIDs.contains(profile.id),
                    onOpen: { selection = .profile(profile.id) },
                    onTogglePower: { on in
                        if on {
                            model.launch(profile)
                        } else if profile.isSteamApp {
                            model.stopSteam()
                        } else {
                            model.closeGame(profile)
                        }
                    }
                )
            }
            if query.isEmpty {
                Button {
                    let profile = model.addProfile()
                    selection = .profile(profile.id)
                } label: {
                    AddGameTile()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 20))
                .foregroundStyle(Onyx.textMute)
            Text("No games match “\(query)”")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Onyx.text)
            Text("Try a different name, or clear the search.")
                .font(.system(size: 11.5))
                .foregroundStyle(Onyx.textMute)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Onyx.hairline2, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        }
    }
}

private struct LibraryTile: View {
    let profile: GameProfile
    var isLive: Bool = false
    var onOpen: () -> Void = {}
    var onTogglePower: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            CoverArt(iconPath: profile.iconPath, label: profile.name,
                     seed: coverSeed(profile.name), corner: 9)
                .frame(height: 88)
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Onyx.text)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Onyx.textMute)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                PowerToggle(isOn: isLive, label: profile.name) { onTogglePower($0) }
            }
            .padding(.horizontal, 3)
            .padding(.bottom, 3)
        }
        .padding(7)
        .background(Onyx.surface, in: RoundedRectangle(cornerRadius: Onyx.tileRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Onyx.tileRadius, style: .continuous)
                .strokeBorder(isLive ? Onyx.good.opacity(0.45) : Onyx.hairline,
                              lineWidth: 0.75)
        }
        .contentShape(Rectangle())
        .onTapGesture { onOpen() }
    }

    private var subtitle: String {
        if profile.isSteamApp { return isLive ? "Steam client · running" : "Steam client" }
        if let id = profile.steamAppID, !id.isEmpty { return "Steam · AppID \(id)" }
        if profile.requiresSteam { return "Uses Steam" }
        return profile.prefix
    }
}

/// Power launch button used on every library tile — glows red when the app is
/// idle, green when it is running. The glow doubles as the live indicator.
private struct PowerToggle: View {
    var isOn: Bool
    var label: String = ""
    var action: (Bool) -> Void

    private var tint: Color { isOn ? Onyx.good : Onyx.accent }

    var body: some View {
        Button { action(!isOn) } label: {
            Image(systemName: "power")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint.opacity(0.16)))
                .overlay { Circle().strokeBorder(tint.opacity(0.55), lineWidth: 1) }
                .shadow(color: tint.opacity(0.85), radius: 5)
                .shadow(color: tint.opacity(0.45), radius: 10)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isOn)
        .help(isOn ? "Stop \(label)" : "Launch \(label)")
    }
}

private struct AddGameTile: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(Onyx.surface, in: Circle())
                .overlay { Circle().strokeBorder(Onyx.hairline, lineWidth: 0.75) }
            Text("Add Game")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Onyx.textDim)
        .frame(maxWidth: .infinity, minHeight: 138)
        .background(Onyx.surface.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: Onyx.tileRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Onyx.tileRadius, style: .continuous)
                .strokeBorder(Onyx.hairline2, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        }
    }
}

private struct EmptyStateView: View {
    let title: String
    let detail: String
    var body: some View {
        Card(title: title, icon: "questionmark.folder.fill") {
            Text(detail)
                .font(.system(size: 12.5))
                .foregroundStyle(Onyx.textDim)
        }
    }
}

// MARK: - Game Detail

private enum GameTab: String, CaseIterable {
    case app = "App", mods = "Mods", launch = "Launch", commands = "Commands"
    var icon: String {
        switch self {
        case .app: return "gamecontroller.fill"
        case .mods: return "square.3.layers.3d"
        case .launch: return "play.fill"
        case .commands: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

private struct GameDetailScreen: View {
    @EnvironmentObject private var model: LauncherModel
    @Binding var profile: GameProfile
    @Binding var selection: SidebarSelection
    @State private var tab: GameTab = .app
    @State private var confirmDelete = false
    @State private var showCoverSearch = false

    private var tabs: [GameTab] {
        profile.supportsModEngine ? GameTab.allCases : [.app, .launch, .commands]
    }

    var body: some View {
        VStack(spacing: 0) {
            hero
            tabBar
            VStack(alignment: .leading, spacing: 14) {
                switch tab {
                case .app:      appTab
                case .mods:     ModsTab(profile: $profile)
                case .launch:   launchTab
                case .commands: commandsTab
                }
            }
            .padding(EdgeInsets(top: 18, leading: 24, bottom: 36, trailing: 24))
        }
        .onChange(of: profile) { _, _ in model.persistProfiles() }
        .sheet(isPresented: $showCoverSearch) {
            CoverSearchSheet(profile: $profile)
                .environmentObject(model)
                .frame(width: 580, height: 560)
        }
        .confirmationDialog("Delete this app profile?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                model.deleteProfile(id: profile.id)
                selection = .library
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // ── Hero ──────────────────────────────────────────────────────────────
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            CoverArt(iconPath: profile.iconPath, label: profile.name,
                     seed: coverSeed(profile.name), corner: 0, showLabel: false)
            LinearGradient(colors: [.clear, Onyx.bg], startPoint: .top, endPoint: .bottom)
            HStack(alignment: .bottom, spacing: 18) {
                CoverArt(iconPath: profile.iconPath, label: profile.name,
                         seed: coverSeed(profile.name), corner: 18)
                    .frame(width: 92, height: 92)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 9) {
                        Text(tagText)
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(Onyx.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Onyx.surface, in: Capsule())
                            .overlay { Capsule().strokeBorder(Onyx.hairline2, lineWidth: 0.75) }
                        Text(profile.prefix)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Onyx.textDim)
                    }
                    Text(profile.name)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Onyx.text)
                    Text("\(profile.executable.isEmpty ? "—" : profile.executable) · prefix: \(profile.prefix) · winver: \(profile.winver)")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Onyx.textDim)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    LaunchStopButton(
                        isLive: model.liveProfileIDs.contains(profile.id),
                        launchTitle: profile.isSteamApp ? "Launch Steam" : "Launch",
                        onLaunch: { model.launch(profile) },
                        onStop: {
                            if profile.isSteamApp { model.stopSteam() }
                            else { model.closeGame(profile) }
                        }
                    )
                }
            }
            .padding(EdgeInsets(top: 24, leading: 24, bottom: 18, trailing: 24))
        }
        .frame(height: 220)
        .clipped()
    }

    private var tagText: String {
        if profile.isSteamApp { return "Steam" }
        if profile.supportsModEngine { return "Modded" }
        if profile.requiresSteam { return "Steam Game" }
        return "Game"
    }

    // ── Tab bar ───────────────────────────────────────────────────────────
    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(tabs, id: \.self) { item in
                let active = tab == item
                Button { tab = item } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon).font(.system(size: 11))
                        Text(item.rawValue).font(.system(size: 12.5, weight: .medium))
                    }
                    .foregroundStyle(active ? Onyx.text : Onyx.textMute)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(active ? Onyx.accent : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .overlay(alignment: .bottom) { Rectangle().fill(Onyx.hairline).frame(height: 1) }
    }

    // ── App tab ───────────────────────────────────────────────────────────
    private var iconPathBinding: Binding<String> {
        Binding(
            get: { profile.iconPath ?? "" },
            set: { profile.iconPath = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }

    @ViewBuilder private var appTab: some View {
        if !profile.isSteamApp {
            CollapsibleCard(
                title: "How launching works",
                icon: "questionmark.circle.fill",
                storageKey: "profile.section.launch-help.collapsed",
                help: "The two ways games run in RipperMoonKit — through Steam, or straight from a game folder."
            ) {
                launchHelpContent
            }
        }

        Card(title: "App Settings", icon: "gamecontroller.fill") {
            VStack(alignment: .leading, spacing: 12) {
                FieldRow(label: "Name") { OnyxField(text: $profile.name) }
                FieldRow(label: "Icon") {
                    CoverArt(iconPath: profile.iconPath, label: profile.name,
                             seed: coverSeed(profile.name), corner: 7)
                        .frame(width: 30, height: 30)
                    OnyxField(text: iconPathBinding, mono: true, trailing: AnyView(
                        HStack(spacing: 6) {
                            Button { showCoverSearch = true } label: {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .foregroundStyle(Onyx.accent)
                            }
                            .buttonStyle(.plain)
                            .help("Find cover art on TheGamesDB")
                            Button { model.chooseIcon(for: &profile) } label: {
                                Image(systemName: "photo").foregroundStyle(Onyx.textMute)
                            }
                            .buttonStyle(.plain)
                            .help("Choose an image file")
                            Button { profile.iconPath = nil } label: {
                                Image(systemName: "xmark.circle").foregroundStyle(Onyx.textMute)
                            }
                            .buttonStyle(.plain)
                            .help("Clear icon")
                        }
                    ))
                }
                FieldRow(label: "Prefix") {
                    OnyxField(text: $profile.prefix)
                    Spacer()
                }
                FieldRow(label: "Winver") {
                    Picker("", selection: $profile.winver) {
                        Text("win10").tag("win10")
                        Text("win11").tag("win11")
                        Text("win7").tag("win7")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220)
                    Spacer()
                }
            }
        }

        CollapsibleCard(
            title: "Paths",
            icon: "folder.fill",
            storageKey: "profile.section.paths.collapsed",
            help: "Where the game, executable, runner, and icon live. These paths let RipperMoonKit launch the right files without hard-coding your machine."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if !profile.isSteamApp {
                    PathEditor(title: "Folder", path: $profile.gameFolder) {
                        model.chooseFolder(current: profile.gameFolder) { profile.gameFolder = $0 }
                    }
                    .help("The folder containing the game's Windows executable. This is the working directory Wine/GPTK enters before launch.")
                    FieldRow(label: "Executable") {
                        OnyxField(text: $profile.executable, mono: true)
                        IconButton(systemImage: "doc.badge.gearshape", help: "Choose executable") {
                            model.chooseExecutable(for: &profile)
                        }
                    }
                    .help("The .exe RipperMoonKit starts for this profile. For Elden Ring Seamless, this is usually ersc_launcher.exe.")
                }
                PathEditor(title: "Runner", path: $profile.runnerPath) {
                    model.chooseFolder(current: profile.runnerPath) { profile.runnerPath = $0 }
                }
                .help("Optional Wine/GPTK runner override. Leave this alone unless a game needs a specific runner build.")
            }
        }
    }

    private var launchHelpContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            pathHintRow(
                icon: "cart.fill",
                title: "A Steam game",
                text: "Open the Steam app from your Library, sign in, and install the game inside Steam. Then launch it from Steam — or set the Folder and Executable below to the installed game."
            )
            pathHintRow(
                icon: "internaldrive.fill",
                title: "A standalone game or repack",
                text: "No Steam needed. Set the Folder and Executable below to the game's .exe, pick the Windows version, then press Launch."
            )
            Button { model.openHelpDocs(page: "gui.html") } label: {
                HStack(spacing: 5) {
                    Image(systemName: "book.fill").font(.system(size: 10))
                    Text("Open the full guide")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Onyx.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private func pathHintRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Onyx.accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Onyx.text)
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(Onyx.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // ── Launch tab ────────────────────────────────────────────────────────
    @ViewBuilder private var launchTab: some View {
        CollapsibleCard(
            title: "Launch Options",
            icon: "switch.2",
            storageKey: "profile.section.launch-options.collapsed",
            help: "Runtime switches passed to GPTK/Wine. These tune compatibility, logging, graphics behavior, and DLL loading for this game."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if profile.isSteamManaged {
                    HStack(spacing: 18) {
                        Toggle("HUD", isOn: $profile.hud)
                            .help("Shows the Metal/GPTK performance overlay while the game runs.")
                        Toggle("No esync", isOn: $profile.noEsync)
                            .help("Disables esync for games or launchers that hang with Wine's eventfd synchronization.")
                    }
                    .toggleStyle(.checkbox)
                } else {
                    FlowLayout(spacing: 18) {
                        Toggle("Steam required", isOn: $profile.requiresSteam)
                            .help("Starts or expects Steam before launch. Use this when the game checks Steam APIs or uses Steam networking.")
                        Toggle("No DXR", isOn: $profile.noDXR)
                            .help("Disables DXR/ray tracing. This avoids unsupported D3D12 paths and often improves stability on Apple GPUs.")
                        Toggle("AVX", isOn: optionalBinding(\.avx))
                            .help("Enables AVX-related launch handling for games that require AVX-capable CPU behavior.")
                        Toggle("MetalFX/DLSS", isOn: optionalBinding(\.metalFX))
                            .help("Enables MetalFX integration where the runner supports it. Useful for upscaling paths exposed by GPTK.")
                        Toggle("HUD", isOn: $profile.hud)
                            .help("Shows the Metal/GPTK performance overlay while the game runs.")
                        Toggle("No esync", isOn: $profile.noEsync)
                            .help("Disables esync for games or launchers that hang with Wine's eventfd synchronization.")
                        Toggle("Native winmm", isOn: $profile.nativeWinmm)
                            .help("Loads a native winmm.dll first. Elden Ring Seamless uses this path for mod DLL loading.")
                        Toggle("Native steam_api64", isOn: $profile.nativeSteamAPI)
                            .help("Loads native steam_api64.dll first so Steam-dependent mods can call the bundled Steam API.")
                    }
                    .toggleStyle(.checkbox)
                    Rectangle().fill(Onyx.hairline).frame(height: 1)
                    FieldRow(label: "DLL overrides") {
                        OnyxField(text: Binding(
                            get: { profile.extraDllOverrides ?? "" },
                            set: { profile.extraDllOverrides = $0.isEmpty ? nil : $0 }
                        ), mono: true)
                    }
                    .help("Extra WINEDLLOVERRIDES entries for this game. Use only when a game or mod needs a specific native/builtin DLL order.")
                    FieldRow(label: "Arguments") {
                        OnyxField(text: $profile.extraArguments, mono: true)
                    }
                    .help("Arguments appended after the executable. Useful for flags like driver checks, renderer options, or game-specific launch switches.")
                }
            }
        }

        Card(title: "Actions", icon: "play.circle.fill") {
          VStack(alignment: .leading, spacing: 12) {
            if profile.isEldenRingERSC {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Onyx.accent)
                    Text("For co-op, open the Steam profile and use Install Spacewar once. Let Steam finish AppID 480 setup, then close Spacewar before launching Elden Ring.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Onyx.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Onyx.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Onyx.hairline, lineWidth: 0.75)
                }
            }

            FlowLayout(spacing: 8) {
                if profile.requiresSteam && !profile.isSteamManaged {
                    RMKButton(kind: .primary, icon: "play.fill", title: "Start Steam") {
                        model.startSteam(for: profile)
                    }
                }
                if profile.isSteamApp {
                    RMKButton(kind: model.steamReady ? .ghost : .primary,
                              icon: model.steamReady ? "wrench.and.screwdriver.fill" : "arrow.down.circle.fill",
                              title: model.steamReady ? "Repair Steam" : "Install Steam") {
                        model.installSteam()
                    }
                    .help("Downloads SteamSetup.exe if needed, runs it in the Steam prefix, then validates that steam.exe exists.")
                }
                RMKButton(kind: .primary, icon: "gamecontroller.fill",
                          title: profile.isSteamApp ? "Launch Steam" : (profile.useModEngine == true ? "Launch Modded" : "Launch"),
                          disabled: profile.isSteamApp && !model.steamReady) {
                    model.launch(profile)
                }
                if profile.isSteamApp {
                    RMKButton(kind: .ghost, icon: "network", title: "Install Spacewar") {
                        model.installSpacewarFromSteam(for: profile)
                    }
                    .help("Launches Steam AppID 480 once so Steam can install Spacewar. Some co-op Steamworks test paths depend on this local Steam state.")
                }
                if !profile.isSteamApp {
                    RMKButton(kind: .ghost, icon: "xmark.circle.fill", title: "Close Game",
                              disabled: model.closeTargets(for: profile).isEmpty) {
                        model.closeGame(profile)
                    }
                }
                if profile.isSteamApp || profile.requiresSteam {
                    RMKButton(kind: .ghost, icon: "power", title: "Close Steam") {
                        model.stopSteam()
                    }
                }
                RMKButton(kind: .ghost, icon: "shippingbox.fill", title: "Install VC++ Runtime") {
                    model.installVCRuntime(for: profile)
                }
                if profile.supportsModEngine {
                    RMKButton(kind: .ghost, icon: "curlybraces", title: "Install .NET 6") {
                        model.installDotNet6(for: profile)
                    }
                }
                RMKButton(kind: .ghost, icon: "puzzlepiece.fill", title: "Install API Stubs") {
                    model.installStubs(for: profile)
                }
                RMKButton(kind: .ghost, icon: "doc.text.magnifyingglass", title: "Logs") {
                    model.openLogsFolder()
                }
                RMKButton(kind: .danger, icon: "trash", title: "Delete",
                          disabled: profile.isRequiredLibraryProfile) {
                    confirmDelete = true
                }
            }
          }
        }

        CollapsibleCard(
            title: "Validation",
            icon: "checkmark.seal.fill",
            storageKey: "profile.section.validation.collapsed",
            defaultCollapsed: true,
            help: "Quick checks for files this profile expects. Missing items here usually mean the path settings need correction."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if profile.isSteamApp {
                    ValidationRow(title: "Steam prefix",
                                  isOK: FileManager.default.fileExists(atPath: model.prefixPath(for: profile)))
                    ValidationRow(title: "steam.exe", isOK: model.steamExecutableExists(in: profile))
                } else if profile.isSteamLibraryGame {
                    ValidationRow(title: "Steam AppID \(profile.steamAppID ?? "")", isOK: true)
                    ValidationRow(title: "Install folder",
                                  isOK: FileManager.default.fileExists(atPath: profile.gameFolder))
                } else if profile.useModEngine == true {
                    ForEach(model.modEngineValidationItems(for: profile), id: \.title) { item in
                        ValidationRow(title: item.title, isOK: item.isOK)
                    }
                } else {
                    ValidationRow(title: profile.executable,
                                  isOK: model.fileExists(profile.executable, in: profile))
                    ForEach(profile.requiredFiles, id: \.self) { item in
                        ValidationRow(title: item, isOK: model.fileExists(item, in: profile))
                    }
                }
                ValidationRow(title: "Runner folder",
                              isOK: profile.runnerPath.isEmpty
                                  || FileManager.default.fileExists(atPath: profile.runnerPath))
            }
        }
    }

    private func optionalBinding(_ keyPath: WritableKeyPath<GameProfile, Bool?>) -> Binding<Bool> {
        Binding(
            get: { profile[keyPath: keyPath] ?? false },
            set: { profile[keyPath: keyPath] = $0 }
        )
    }

    // ── Commands tab ──────────────────────────────────────────────────────
    @ViewBuilder private var commandsTab: some View {
        CollapsibleCard(
            title: "Resolved Commands",
            icon: "chevron.left.forwardslash.chevron.right",
            storageKey: "profile.section.resolved-commands.collapsed",
            defaultCollapsed: true,
            help: "The exact shell commands RipperMoonKit will run after applying this profile's paths, prefix, DLL overrides, and launch flags."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if profile.requiresSteam && !profile.isSteamManaged {
                    CommandPreview(title: "Start Steam",
                                   command: model.previewStartSteamCommand(for: profile))
                    .help("Starts Steam in the configured prefix before launching a game that depends on Steam services.")
                }
                if profile.isSteamManaged {
                    if profile.isSteamApp {
                        CommandPreview(title: model.steamReady ? "Repair Steam" : "Install Steam",
                                       command: model.previewInstallSteamCommand())
                        .help("Runs the Steam installer in the Steam prefix and validates steam.exe after the installer exits.")
                    }
                    CommandPreview(title: profile.isSteamApp ? "Launch Steam" : "Launch From Steam",
                                   command: model.previewSteamManagedLaunchCommand(for: profile))
                    .help("Launches Steam directly, or asks Steam to launch the selected AppID.")
                    if profile.isSteamApp {
                        CommandPreview(title: "Install Spacewar",
                                       command: model.previewInstallSpacewarCommand(for: profile))
                        .help("Launches AppID 480 from Steam so Steam can install Spacewar for Steamworks co-op test paths.")
                    }
                } else if profile.useModEngine == true {
                    CommandPreview(title: "Launch Modded",
                                   command: model.previewModEngineLaunchCommand(for: profile))
                    .help("Runs ModEngine2 through GPTK/Wine and points it at the selected game executable.")
                    CommandPreview(title: "Run Randomizer",
                                   command: model.previewRandomizerCommand(for: profile))
                    .help("Starts the Elden Ring Randomizer GUI in the tools prefix so you can import options and generate mod files.")
                } else {
                    CommandPreview(title: "Launch",
                                   command: model.previewLaunchCommand(for: profile))
                    .help("Runs the configured executable directly through GPTK/Wine.")
                }
                if !profile.isSteamApp && !model.closeTargets(for: profile).isEmpty {
                    CommandPreview(title: "Close Game",
                                   command: model.previewCloseGameCommand(for: profile))
                    .help("Terminates this game's Windows processes without closing Steam.")
                }
                if profile.isSteamApp || profile.requiresSteam {
                    CommandPreview(title: "Close Steam",
                                   command: model.previewStopSteamCommand())
                    .help("Stops Steam and its helper processes when you are done using Steam-dependent games.")
                }
            }
        }
        ActivityCard()
    }
}

private struct ModsTab: View {
    @EnvironmentObject private var model: LauncherModel
    @Binding var profile: GameProfile

    var body: some View {
        Card(title: "Mod Stack", icon: "square.3.layers.3d", trailing: AnyView(
            Toggle("Launch through ModEngine", isOn: Binding(
                get: { profile.useModEngine ?? false },
                set: { profile.useModEngine = $0 }
            ))
            .toggleStyle(.checkbox)
            .font(.system(size: 11.5))
            .foregroundStyle(Onyx.textDim)
            .help("Routes launch through ModEngine2 instead of starting the game executable directly.")
        )) {
            VStack(alignment: .leading, spacing: 10) {
                modLayer(1, "Seamless Coop", "DLL",
                         profile.seamlessDllPath ?? "../SeamlessCoop/ersc.dll")
                modLayer(2, "Elden Ring Randomizer", "EXE",
                         profile.randomizerExecutable ?? "randomizer/EldenRingRandomizer.exe")
                modLayer(3, "ModEngine 2", "Loader",
                         "\(profile.modEngineLauncher ?? "modengine2_launcher.exe") · \(profile.modEngineConfig ?? "config_eldenring.toml")")
            }
        }

        CollapsibleCard(
            title: "Mod Configuration",
            icon: "wrench.adjustable.fill",
            storageKey: "profile.section.mod-configuration.collapsed",
            defaultCollapsed: true,
            help: "Advanced ModEngine paths. These tell RipperMoonKit where the ModEngine launcher, config, batch file, Randomizer, and Seamless DLL are located."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                PathEditor(title: "ModEngine", path: Binding(
                    get: { profile.modEngineFolder ?? "ModEngine2" },
                    set: { profile.modEngineFolder = $0.isEmpty ? nil : $0 }
                )) {
                    model.chooseFolder(current: model.modEngineDirectory(for: profile)) { selected in
                        profile.modEngineFolder = model.profileRelativePath(selected, from: profile.gameFolder)
                    }
                }
                .help("Folder containing modengine2_launcher.exe. Usually Game/ModEngine2.")
                FieldRow(label: "Launch Bat") {
                    OnyxField(text: optional(\.modEngineLaunchBat, "launchmod_eldenring.bat"), mono: true)
                }
                .help("Optional batch file mirroring the ModEngine launch command. Useful for compatibility with setups copied from Windows.")
                FieldRow(label: "Config") {
                    OnyxField(text: optional(\.modEngineConfig, "config_eldenring.toml"), mono: true)
                }
                .help("The ModEngine TOML file that lists external DLLs and mod folders.")
                FieldRow(label: "Launcher") {
                    OnyxField(text: optional(\.modEngineLauncher, "modengine2_launcher.exe"), mono: true)
                }
                .help("The ModEngine executable RipperMoonKit launches.")
                FieldRow(label: "Randomizer") {
                    OnyxField(text: optional(\.randomizerExecutable, "randomizer/EldenRingRandomizer.exe"), mono: true)
                }
                .help("The Randomizer GUI executable relative to the ModEngine folder.")
                FieldRow(label: "Seamless DLL") {
                    OnyxField(text: optional(\.seamlessDllPath, "../SeamlessCoop/ersc.dll"), mono: true)
                }
                .help("The Seamless Co-op DLL path as written into ModEngine config. It is usually relative to ModEngine2.")
            }
        }

        CollapsibleCard(
            title: "Mod Files",
            icon: "wrench.and.screwdriver.fill",
            storageKey: "profile.section.mod-files.collapsed",
            help: "Install, back up, import, prepare, randomize, and launch the Elden Ring mod toolchain."
        ) {
            FlowLayout(spacing: 8) {
                RMKButton(kind: .primary, icon: "square.and.arrow.down.fill",
                          title: "Install ModEngine + Randomizer") {
                    model.installModEngineRandomizerProfile(for: profile)
                }
                .help("Installs the standard ModEngine2, Randomizer, Seamless Co-op, and related setup files for this profile.")
                RMKButton(kind: .ghost, icon: "externaldrive.badge.timemachine", title: "Backup Mod State") {
                    model.backupEldenModState(for: profile)
                }
                .help("Creates a rollback backup of ModEngine2, SeamlessCoop, and the mod helper executables.")
                RMKButton(kind: .ghost, icon: "person.2.badge.gearshape.fill", title: "Import From Friend") {
                    model.importFriendKit(for: profile)
                }
                .help("Imports a host's friend kit: bundled mod ZIPs, Randomizer options, and Seamless password.")
                RMKButton(kind: .ghost, icon: "archivebox.fill", title: "Install Mod Zips") {
                    model.installModZips(for: profile)
                }
                .help("Manually install selected ModEngine, Randomizer, Seamless, or anti-cheat toggler ZIP files.")
                RMKButton(kind: .ghost, icon: "wrench.adjustable.fill", title: "Prepare Mod Files") {
                    model.prepareModEngine(for: profile)
                }
                .help("Rewrites the ModEngine config and launch batch file for this Mac path.")
                RMKButton(kind: .ghost, icon: "shuffle", title: "Run Randomizer") {
                    model.runRandomizer(for: profile)
                }
                .help("Opens the Randomizer GUI. Import a .randomizeopt file there, then click Randomize.")
                RMKButton(kind: .primary, icon: "play.circle.fill", title: "Launch Modded") {
                    model.launchModEngine(profile)
                }
                .help("Launches Elden Ring through ModEngine2 with the current mod configuration.")
            }
        }
    }

    private func optional(_ keyPath: WritableKeyPath<GameProfile, String?>,
                          _ fallback: String) -> Binding<String> {
        Binding(
            get: { profile[keyPath: keyPath] ?? fallback },
            set: { profile[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func modLayer(_ n: Int, _ name: String, _ type: String, _ desc: String) -> some View {
        HStack(spacing: 12) {
            Text("\(n)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Onyx.accentInk)
                .frame(width: 26, height: 26)
                .background(Onyx.accent, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Onyx.text)
                    Text(type)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(Onyx.textDim)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Onyx.surface2, in: Capsule())
                        .overlay { Capsule().strokeBorder(Onyx.hairline, lineWidth: 0.75) }
                }
                Text(desc)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Onyx.textMute)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}

private struct CommandPreview: View {
    let title: String
    let command: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Onyx.textDim)
            Text(command)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Onyx.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(Onyx.bgDeep, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Onyx.hairline2, lineWidth: 0.75)
                }
        }
    }
}

private struct ActivityCard: View {
    @EnvironmentObject private var model: LauncherModel
    var body: some View {
        Card(title: "Activity", icon: "waveform.path.ecg", trailing: AnyView(
            HStack(spacing: 6) {
                if model.isRunning { ProgressView().controlSize(.small) }
                Text(model.lastResult)
                    .font(.system(size: 11))
                    .foregroundStyle(Onyx.textMute)
            }
        )) {
            Terminal(title: "rippermoon.log", text: model.commandOutput, live: model.isRunning)
                .frame(minHeight: 150)
        }
    }
}

// MARK: - Backups

private struct BackupsScreen: View {
    @EnvironmentObject private var model: LauncherModel
    @State private var selected: BackupItem.ID?
    @State private var confirmRollback = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Card(title: "Update Safeguards", icon: "externaldrive.badge.timemachine") {
                HStack(spacing: 14) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 20))
                        .foregroundStyle(Onyx.accent)
                        .frame(width: 42, height: 42)
                        .background(Onyx.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Onyx.hairline2, lineWidth: 0.75)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Update Safeguards")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Onyx.text)
                        Text("\(model.backups.count) snapshots · Auto-snapshot before every update")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Onyx.textDim)
                    }
                    Spacer()
                    RMKButton(kind: .primary, icon: "plus.circle.fill", title: "Create Backup") {
                        model.createBackupOnly()
                    }
                    RMKButton(kind: .ghost, icon: "arrow.clockwise", title: "Refresh") {
                        model.refreshBackups()
                    }
                    RMKButton(kind: .danger, icon: "arrow.uturn.backward",
                              title: "Rollback", disabled: selected == nil) {
                        confirmRollback = true
                    }
                }
            }

            Card(title: "Snapshots", icon: "archivebox.fill") {
                if model.backups.isEmpty {
                    Text("No snapshots yet. Create a backup before your next update.")
                        .font(.system(size: 12))
                        .foregroundStyle(Onyx.textMute)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 1) {
                        ForEach(Array(model.backups.enumerated()), id: \.element.id) { index, backup in
                            snapshotRow(backup, index: index)
                        }
                    }
                }
            }
        }
        .padding(EdgeInsets(top: 20, leading: 24, bottom: 40, trailing: 24))
        .confirmationDialog("Rollback selected backup?", isPresented: $confirmRollback) {
            Button("Rollback", role: .destructive) {
                if let selected { model.rollbackBackup(id: selected) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func snapshotRow(_ backup: BackupItem, index: Int) -> some View {
        let isSel = selected == backup.id
        let phase = Double(model.backups.count - index) / Double(max(model.backups.count, 1))
        return Button {
            selected = backup.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: moonSymbol(phase))
                    .font(.system(size: 13))
                    .foregroundStyle(index == 0 ? Onyx.accent : Onyx.textDim)
                    .frame(width: 26, height: 26)
                    .background(index == 0 ? Onyx.surface2 : .clear,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 8) {
                        Text(backup.name)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(Onyx.text)
                        if index == 0 {
                            Text("CURRENT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Onyx.good)
                                .padding(.horizontal, 6).padding(.vertical, 1.5)
                                .background(Onyx.surface2, in: Capsule())
                        }
                    }
                    Text(backup.path)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(Onyx.textMute)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Onyx.textMute)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSel ? Onyx.surface2 : .clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func moonSymbol(_ phase: Double) -> String {
        switch phase {
        case ..<0.2:  return "moonphase.new.moon.inverse"
        case ..<0.4:  return "moonphase.waxing.crescent.inverse"
        case ..<0.6:  return "moonphase.first.quarter.inverse"
        case ..<0.8:  return "moonphase.waxing.gibbous.inverse"
        default:      return "moonphase.full.moon.inverse"
        }
    }
}

// MARK: - Settings

private struct SettingsScreen: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Card(title: "Paths", icon: "folder.fill") {
                VStack(alignment: .leading, spacing: 9) {
                    PathEditor(title: "GPTK Home", path: $model.pathSettings.gptkHome) {
                        model.chooseFolder(current: model.pathSettings.gptkHome) { model.pathSettings.gptkHome = $0 }
                    }
                    PathEditor(title: "Prefix Root", path: $model.pathSettings.prefixRoot) {
                        model.chooseFolder(current: model.pathSettings.prefixRoot) { model.pathSettings.prefixRoot = $0 }
                    }
                    PathEditor(title: "Games Root", path: $model.pathSettings.gamesRoot) {
                        model.chooseFolder(current: model.pathSettings.gamesRoot) { model.pathSettings.gamesRoot = $0 }
                    }
                    PathEditor(title: "External Root", path: $model.pathSettings.externalRoot) {
                        model.chooseFolder(current: model.pathSettings.externalRoot) { model.pathSettings.externalRoot = $0 }
                    }
                    PathEditor(title: "Steam Library", path: $model.pathSettings.steamLibrary) {
                        model.chooseFolder(current: model.pathSettings.steamLibrary) { model.pathSettings.steamLibrary = $0 }
                    }
                    PathEditor(title: "Toolkit Source", path: $model.toolkitSourceFolder) {
                        model.chooseFolder(current: model.toolkitSourceFolder) { model.toolkitSourceFolder = $0 }
                    }
                    HStack {
                        Spacer()
                        RMKButton(kind: .primary, icon: "square.and.arrow.down.fill", title: "Save Paths") {
                            model.savePathSettings()
                        }
                    }
                }
            }

            Card(title: "Drive Mappings", icon: "externaldrive.connected.to.line.below.fill",
                 trailing: AnyView(
                    RMKButton(kind: .ghost, icon: "plus", title: "Add Drive", small: true) {
                        model.addDriveMap()
                    }
                 )) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach($model.driveMaps) { $drive in
                        HStack(spacing: 9) {
                            Text("\(drive.letter):")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(Onyx.accent)
                                .frame(width: 38, height: 30)
                                .background(Onyx.bgDeep, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Onyx.hairline, lineWidth: 0.75)
                                }
                            OnyxField(text: $drive.path, mono: true)
                            IconButton(systemImage: "folder", help: "Choose folder") {
                                model.chooseFolder(current: drive.path) { drive.path = $0 }
                            }
                            IconButton(systemImage: "minus.circle", help: "Remove drive") {
                                model.removeDriveMap(id: drive.id)
                            }
                        }
                    }
                    HStack {
                        Spacer()
                        RMKButton(kind: .primary, icon: "square.and.arrow.down.fill", title: "Save Drives") {
                            model.saveDriveMaps()
                        }
                    }
                }
            }

            Card(title: "Maintenance", icon: "wrench.and.screwdriver.fill") {
                VStack(alignment: .leading, spacing: 14) {
                    if let notice = model.updateNotice {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Onyx.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("RipperMoonKit \(notice.version) is available on GitHub.")
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(Onyx.text)
                                Text("Use Update From GitHub below. The app will close and reopen after the update installs.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Onyx.textDim)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(Onyx.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Onyx.accent.opacity(0.35), lineWidth: 0.8)
                        }
                    }
                    FlowLayout(spacing: 8) {
                        RMKButton(kind: .primary, icon: "square.and.arrow.down.fill", title: "Install Toolkit") {
                            model.installToolkit()
                        }
                        RMKButton(kind: .ghost, icon: "externaldrive.fill.badge.plus", title: "Begin GPTK Install") {
                            model.beginGPTKInstall()
                        }
                        RMKButton(kind: .ghost, icon: "arrow.clockwise", title: "Check for Updates") {
                            Task { await model.checkForAvailableUpdate(force: true) }
                        }
                        RMKButton(kind: .ghost, icon: "arrow.down.circle.fill", title: "Update From GitHub") {
                            model.updateFromGitHub()
                        }
                        RMKButton(kind: .ghost, icon: "shippingbox.fill", title: "Install VC++ Runtime") {
                            model.installVCRuntimeGlobally()
                        }
                        RMKButton(kind: .ghost, icon: "puzzlepiece.fill", title: "Install API Stubs") {
                            model.installStubsGlobally()
                        }
                    }
                    Rectangle().fill(Onyx.hairline).frame(height: 1)
                    HStack(spacing: 18) {
                        Toggle("Remove config", isOn: $model.removeConfigOnUninstall)
                        Toggle("Remove Wine prefixes and saves", isOn: $model.removePrefixesOnUninstall)
                        Spacer()
                        RMKButton(kind: .danger, icon: "trash", title: "Uninstall Toolkit") {
                            model.uninstallToolkit()
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }

            Card(title: "Cover Art · TheGamesDB", icon: "photo.on.rectangle.angled") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cover-art search uses TheGamesDB. Add your own API key — a free key is available at thegamesdb.net.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Onyx.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                    FieldRow(label: "API Key") {
                        OnyxField(text: $model.tgdbAPIKeyLocal,
                                  placeholder: "TheGamesDB API key", mono: true)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: model.tgdbAPIKey.isEmpty
                              ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(model.tgdbAPIKey.isEmpty ? Onyx.warn : Onyx.good)
                        Text(model.tgdbAPIKey.isEmpty
                             ? "No key set — cover search is disabled"
                             : "Cover search ready")
                            .font(.system(size: 11))
                            .foregroundStyle(Onyx.textMute)
                        Spacer()
                        RMKButton(kind: .primary, icon: "square.and.arrow.down.fill",
                                  title: "Save Key") {
                            model.saveTGDBKey()
                        }
                    }
                }
            }

            ActivityCard()
        }
        .padding(EdgeInsets(top: 20, leading: 24, bottom: 40, trailing: 24))
    }
}

// MARK: - Setup guide

private struct SetupGuideView: View {
    @EnvironmentObject private var model: LauncherModel
    @State private var showAdvanced = false

    private var checks: [SetupCheck] { model.setupChecks }
    private var coreChecks: [SetupCheck] { checks.filter { !$0.isOptional } }
    /// "Ready to game" depends only on the required pieces — Steam is optional.
    private var coreReady: Bool { coreChecks.allSatisfy(\.isOK) }
    private var readyCount: Int { coreChecks.filter(\.isOK).count }
    private var gptkDownloadURL: URL {
        URL(string: model.config.gptkDownloadPage) ?? URL(string: "https://developer.apple.com/games/game-porting-toolkit/")!
    }

    var body: some View {
        Group {
            if coreReady {
                successView
            } else if model.awaitingGPTKDownload && !model.config.hasLocalGPTK {
                gptkDownloadView
            } else {
                progressView
            }
        }
        .padding(24)
        .background(Onyx.bg)
        .task {
            // Auto-recheck: the checklist ticks itself off, no button needed.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if Task.isCancelled { break }
                model.refreshSetupChecks()
            }
        }
    }

    // MARK: - In-progress

    private var progressView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                BrandMark(size: 52, glow: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Setting up RipperMoonKit")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Onyx.text)
                    Text("One click installs everything. macOS asks for your Mac password once, and Apple's Game Porting Toolkit is the only file you download yourself.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Onyx.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Text("\(readyCount) of \(coreChecks.count) ready")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Onyx.textMute)
                    .fixedSize()
                ProgressView(value: Double(readyCount), total: Double(coreChecks.count))
                    .tint(Onyx.accent)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(checks) { check in
                    SetupRow(check: check)
                }
            }
            .padding(14)
            .background(Onyx.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Onyx.hairline, lineWidth: 0.75)
            }

            if !model.config.hasLocalGPTK {
                gptkNotice
            }

            if model.guidedSetupRunning {
                HStack(alignment: .top, spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Setup is running in the Terminal window. Each item above ticks off on its own as it installs. The app only moves forward after GPTK 3.0 is mounted, copied, and verified.")
                        .font(.system(size: 12))
                        .foregroundStyle(Onyx.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            RMKButton(kind: .primary, icon: "sparkles",
                      title: model.guidedSetupRunning ? "Restart Setup" : "Set Up RipperMoonKit") {
                model.startFirstRunSetup()
            }

            DisclosureGroup(isExpanded: $showAdvanced) {
                FlowLayout(spacing: 8) {
                    RMKButton(kind: .ghost, icon: "arrow.down.circle", title: "Prepare Source", small: true) {
                        model.prepareToolkitSource()
                    }
                    RMKButton(kind: .ghost, icon: "square.and.arrow.down", title: "Install Toolkit", small: true) {
                        model.installToolkit()
                    }
                    RMKButton(kind: .ghost, icon: "externaldrive.badge.plus", title: "Begin GPTK Install", small: true) {
                        model.beginGPTKInstall()
                    }
                }
                .padding(.top, 10)
            } label: {
                Text("Advanced — run individual steps")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Onyx.textMute)
            }
            .tint(Onyx.textDim)

            HStack {
                Spacer()
                Button("Set up later") { model.deferSetup() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Onyx.textMute)
                Spacer()
            }
        }
    }

    private var gptkNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("One step needs you", systemImage: "person.badge.key.fill")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Onyx.text)
            Text("Download Game Porting Toolkit 3.0 from Apple Developer. Sign in with a free Apple Developer account, download the evaluation environment DMG, then open it so it mounts. RipperMoonKit will stay here until GPTK 3.0 is processed and verified.")
                .font(.system(size: 11.5))
                .foregroundStyle(Onyx.textDim)
                .fixedSize(horizontal: false, vertical: true)
            Link(destination: gptkDownloadURL) {
                Text("Open Apple's Game Porting Toolkit 3.0 download page")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Onyx.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Onyx.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Onyx.accent.opacity(0.4), lineWidth: 0.75)
        }
    }

    private var gptkDownloadView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                BrandMark(size: 52, glow: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Download Game Porting Toolkit 3.0")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Onyx.text)
                    Text("This is the only required file RipperMoonKit cannot bundle. Download it from Apple, open the DMG, then come back here. Installation will not start until the GPTK download or mount is detected.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Onyx.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("What to do now", systemImage: "externaldrive.badge.plus")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Onyx.text)
                Text("1. Sign in with a free Apple Developer account.\n2. Download Game Porting Toolkit 3.0.\n3. Open the downloaded DMG so it appears in Finder.\n4. Return here when the button below becomes available.")
                    .font(.system(size: 12))
                    .foregroundStyle(Onyx.textDim)
                    .fixedSize(horizontal: false, vertical: true)
                Link(destination: gptkDownloadURL) {
                    Text("Open Apple's Game Porting Toolkit 3.0 download page")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Onyx.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Onyx.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Onyx.accent.opacity(0.4), lineWidth: 0.75)
            }

            Label(model.config.gptkInstallMediaStatus, systemImage: model.config.hasGPTKInstallMedia ? "checkmark.circle.fill" : "clock.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(model.config.hasGPTKInstallMedia ? Onyx.good : Onyx.textDim)

            RMKButton(
                kind: .primary,
                icon: "externaldrive.badge.checkmark",
                title: model.config.hasGPTKInstallMedia ? "Begin GPTK Install" : "Waiting for GPTK Download",
                disabled: !model.config.hasGPTKInstallMedia
            ) {
                model.beginGPTKInstall()
            }

            HStack {
                Spacer()
                Button("Set up later") { model.deferSetup() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Onyx.textMute)
                Spacer()
            }
        }
        .onAppear {
            model.openGPTKPageForCurrentSetupIfNeeded()
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 16) {
            BrandMark(size: 64, glow: true)

            VStack(spacing: 5) {
                Text("You're all set")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Onyx.text)
                Text("Every required piece is installed. The Mac is ready to reap — go play something.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Onyx.textDim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            RMKButton(kind: .primary, icon: "gamecontroller.fill", title: "Start Gaming") {
                model.finishSetup()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("OPTIONAL — YOU MIGHT ALSO WANT TO:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Onyx.textMute)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !model.steamReady {
                    optionalCard(
                        icon: "arrow.down.app.fill",
                        title: "Finish Steam setup",
                        detail: "Install Windows Steam to play your Steam library. Non-Steam games don't need it.",
                        action: "Open Steam"
                    ) { model.goToSteamSetup() }
                }
                optionalCard(
                    icon: "folder.fill",
                    title: "Set your games folder",
                    detail: "Tell RipperMoonKit where your game files live so it can find and launch them.",
                    action: "Settings"
                ) { model.openSetupRelatedSettings() }
                optionalCard(
                    icon: "photo.fill",
                    title: "Add cover art",
                    detail: "Add a free TheGamesDB API key to pull box-art for your game tiles.",
                    action: "Settings"
                ) { model.openSetupRelatedSettings() }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private func optionalCard(icon: String, title: String, detail: String,
                              action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Onyx.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Onyx.text)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Onyx.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            RMKButton(kind: .ghost, title: action, small: true, action: perform)
        }
        .padding(12)
        .background(Onyx.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Onyx.hairline, lineWidth: 0.75)
        }
    }
}

private struct SetupRow: View {
    let check: SetupCheck

    private var statusLabel: String {
        if check.isOK { return "Ready" }
        return check.isOptional ? "Optional" : "Pending"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: check.isOK ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(check.isOK ? Onyx.good : Onyx.textMute)
            VStack(alignment: .leading, spacing: 2) {
                Text(check.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Onyx.text)
                Text(check.explanation)
                    .font(.system(size: 11))
                    .foregroundStyle(Onyx.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(statusLabel)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(check.isOK ? Onyx.good : Onyx.textMute)
        }
        .help(check.detail)
    }
}

/// Persistent bar shown when setup is unfinished and the window is closed.
private struct SetupBanner: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .bold))
            Text("Setup isn't finished — games can't launch yet.")
                .font(.system(size: 11.5, weight: .semibold))
            Spacer()
            Button { model.reopenSetupGuide() } label: {
                Text("Finish Setup")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Onyx.accent)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 4)
                    .background(Color.white, in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Onyx.accentInk)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Onyx.accent)
    }
}

// MARK: - TheGamesDB

/// Minimal TheGamesDB client — used to fetch box-art covers for game profiles.
/// The API key is supplied by the caller; it is never embedded in source.
private enum TheGamesDB {
    struct Match: Identifiable, Hashable {
        let id: Int
        let title: String
        let year: String?
        let thumbURL: URL?
        let fullURL: URL?
    }

    enum ServiceError: LocalizedError {
        case noKey, badResponse, http(Int)
        var errorDescription: String? {
            switch self {
            case .noKey:        return "No TheGamesDB API key. Add one in Settings › Cover Art."
            case .badResponse:  return "TheGamesDB returned an unexpected response."
            case .http(let c):  return "TheGamesDB request failed (HTTP \(c))."
            }
        }
    }

    private struct SearchResponse: Decodable {
        struct GamesBlock: Decodable { let games: [Game] }
        struct Game: Decodable { let id: Int; let gameTitle: String; let releaseDate: String? }
        struct IncludeBlock: Decodable { let boxart: Boxart }
        struct Boxart: Decodable { let baseUrl: BaseURL; let data: [String: [Art]] }
        struct BaseURL: Decodable { let thumb: String; let original: String }
        struct Art: Decodable { let type: String; let side: String?; let filename: String }
        let data: GamesBlock
        let include: IncludeBlock?
    }

    /// Searches games by name and resolves a front box-art image for each result.
    static func search(name: String, apiKey: String) async throws -> [Match] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard !apiKey.isEmpty else { throw ServiceError.noKey }

        var comps = URLComponents(string: "https://api.thegamesdb.net/v1.1/Games/ByGameName")!
        comps.queryItems = [
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "name", value: trimmed),
            URLQueryItem(name: "include", value: "boxart"),
        ]
        guard let url = comps.url else { throw ServiceError.badResponse }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.badResponse }
        guard http.statusCode == 200 else { throw ServiceError.http(http.statusCode) }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(SearchResponse.self, from: data)
        let boxart = decoded.include?.boxart

        return decoded.data.games.map { game in
            let arts = boxart?.data[String(game.id)] ?? []
            let front = arts.first { ($0.side ?? "") == "front" && $0.type == "boxart" }
                ?? arts.first { $0.type == "boxart" }
            let thumb = front.flatMap { art in
                (boxart?.baseUrl.thumb).flatMap { URL(string: $0 + art.filename) }
            }
            let full = front.flatMap { art in
                (boxart?.baseUrl.original).flatMap { URL(string: $0 + art.filename) }
            }
            let year = game.releaseDate?.split(separator: "-").first.map(String.init)
            return Match(id: game.id, title: game.gameTitle, year: year,
                         thumbURL: thumb, fullURL: full)
        }
    }

    /// Downloads raw image bytes for a resolved cover.
    static func download(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.badResponse }
        guard http.statusCode == 200 else { throw ServiceError.http(http.statusCode) }
        return data
    }
}

// MARK: - Cover search sheet

private struct CoverSearchSheet: View {
    @EnvironmentObject private var model: LauncherModel
    @Environment(\.dismiss) private var dismiss
    @Binding var profile: GameProfile

    @State private var query: String
    @State private var results: [TheGamesDB.Match] = []
    @State private var status: Status = .start
    @State private var applyingID: Int?

    private enum Status: Equatable { case start, loading, empty, failed(String), ready }

    init(profile: Binding<GameProfile>) {
        _profile = profile
        _query = State(initialValue: profile.wrappedValue.name)
    }

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            Rectangle().fill(Onyx.hairline).frame(height: 1)
            content
        }
        .background(Onyx.bg)
        .onAppear { if results.isEmpty { runSearch() } }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 16))
                .foregroundStyle(Onyx.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Find Cover Art")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Onyx.text)
                Text("TheGamesDB")
                    .font(.system(size: 11))
                    .foregroundStyle(Onyx.textMute)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Onyx.textDim)
                    .frame(width: 24, height: 24)
                    .background(Onyx.surface2, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(Onyx.textDim)
                TextField("Game title", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Onyx.text)
                    .onSubmit { runSearch() }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Onyx.bgDeep, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Onyx.hairline, lineWidth: 0.75)
            }
            RMKButton(kind: .primary, icon: "magnifyingglass", title: "Search") { runSearch() }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder private var content: some View {
        switch status {
        case .start:
            stateView {
                Text("Search for a game to pick its cover.")
                    .font(.system(size: 12)).foregroundStyle(Onyx.textMute)
            }
        case .loading:
            stateView {
                ProgressView().controlSize(.small)
                Text("Searching TheGamesDB…")
                    .font(.system(size: 12)).foregroundStyle(Onyx.textMute)
            }
        case .empty:
            stateView {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20)).foregroundStyle(Onyx.textMute)
                Text("No matches for “\(query)”.")
                    .font(.system(size: 12)).foregroundStyle(Onyx.textMute)
            }
        case .failed(let message):
            stateView {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 20)).foregroundStyle(Onyx.warn)
                Text(message)
                    .font(.system(size: 12)).foregroundStyle(Onyx.textMute)
                    .multilineTextAlignment(.center)
            }
        case .ready:
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(results) { resultTile($0) }
                }
                .padding(16)
            }
        }
    }

    private func stateView<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 10) { content() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
    }

    private func resultTile(_ match: TheGamesDB.Match) -> some View {
        Button { apply(match) } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    Rectangle().fill(Onyx.surface2)
                    AsyncImage(url: match.thumbURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            Image(systemName: "photo").foregroundStyle(Onyx.textMute)
                        default:
                            ProgressView().controlSize(.small)
                        }
                    }
                    if applyingID == match.id {
                        Color.black.opacity(0.5)
                        ProgressView().controlSize(.small)
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(match.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Onyx.text)
                    .lineLimit(1)
                Text(match.year ?? "Unknown year")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Onyx.textMute)
            }
            .padding(8)
            .background(Onyx.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Onyx.hairline, lineWidth: 0.75)
            }
        }
        .buttonStyle(.plain)
        .disabled(applyingID != nil || match.fullURL == nil)
    }

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { status = .start; return }
        status = .loading
        Task {
            do {
                let found = try await TheGamesDB.search(name: q, apiKey: model.tgdbAPIKey)
                results = found
                status = found.isEmpty ? .empty : .ready
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    private func apply(_ match: TheGamesDB.Match) {
        guard match.fullURL != nil else { return }
        applyingID = match.id
        Task {
            await model.saveCover(match, for: profile.id)
            applyingID = nil
            dismiss()
        }
    }
}

private extension LauncherModel {
    /// The effective TheGamesDB key — the key entered in Settings, stored locally
    /// in user defaults. Seeded once from GPTK_TGDB_API_KEY in the env file.
    var tgdbAPIKey: String {
        tgdbAPIKeyLocal.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // ── Pinned sidebar games ──────────────────────────────────────────────

    /// Pinned profiles, in pin order, resolved against the current library.
    var pinnedProfiles: [GameProfile] {
        pinnedProfileIDs.compactMap { id in profiles.first { $0.id == id } }
    }

    /// Profiles not currently pinned — the candidates for the Add menu.
    var unpinnedProfiles: [GameProfile] {
        profiles.filter { !pinnedProfileIDs.contains($0.id) }
    }

    func pinProfile(_ id: UUID) {
        guard !pinnedProfileIDs.contains(id) else { return }
        pinnedProfileIDs.append(id)
        persistPins()
    }

    func unpinProfile(_ id: UUID) {
        pinnedProfileIDs.removeAll { $0 == id }
        persistPins()
    }

    func persistPins() {
        defaults.set(pinnedProfileIDs.map { $0.uuidString }, forKey: pinnedProfilesKey)
    }

    /// Polls the process list and marks profiles whose game executable is running.
    ///
    /// Uses `ps -axww` so long Wine command lines are not truncated (the default
    /// `ps` width hides the `.exe` deep in a GPTK launch line). Each row is parsed
    /// as PID + state + command so the launcher's own process and dead/zombie
    /// entries can be excluded before matching executable names.
    func refreshLiveStatus() async {
        let result = await ShellExecutor.run("ps -axww -o pid=,state=,command=")
        guard !result.output.isEmpty else { return }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        var entries: [(pid: Int32, command: String)] = []
        for line in result.output.split(separator: "\n") {
            let fields = line.trimmingCharacters(in: .whitespaces)
                .split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard fields.count == 3,
                  let pid = Int32(fields[0]), pid != ownPID,
                  !fields[1].contains("Z") else { continue }   // skip self + zombies
            entries.append((pid, fields[2].lowercased()))
        }

        var live: Set<UUID> = []
        var pidMap: [UUID: [Int32]] = [:]
        for profile in profiles {
            var targets = closeTargets(for: profile)
            if profile.isSteamApp { targets.append(contentsOf: ["steam.exe", "steamwebhelper"]) }
            let needles = targets.map { $0.lowercased() }.filter { !$0.isEmpty }
            guard !needles.isEmpty else { continue }
            let pids = entries
                .filter { entry in needles.contains { entry.command.contains($0) } }
                .map(\.pid)
            if !pids.isEmpty {
                live.insert(profile.id)
                pidMap[profile.id] = pids
            }
        }
        if live != liveProfileIDs { liveProfileIDs = live }
        liveProfilePIDs = pidMap
    }

    /// Persists the Settings-entered TheGamesDB key to local user defaults.
    func saveTGDBKey() {
        let trimmed = tgdbAPIKeyLocal.trimmingCharacters(in: .whitespacesAndNewlines)
        tgdbAPIKeyLocal = trimmed
        defaults.set(trimmed, forKey: tgdbAPIKeyDefaultsKey)
        lastResult = trimmed.isEmpty ? "TheGamesDB key cleared" : "TheGamesDB key saved"
    }

    /// Downloads a chosen cover, caches it under GPTK Home, and assigns it to a profile.
    func saveCover(_ match: TheGamesDB.Match, for profileID: UUID) async {
        guard let url = match.fullURL else {
            lastResult = "That result has no cover image."
            return
        }
        isRunning = true
        defer { isRunning = false }
        do {
            let data = try await TheGamesDB.download(url)
            let directory = "\(pathSettings.gptkHome)/covers"
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            let destination = "\(directory)/tgdb-\(match.id).\(ext)"
            try data.write(to: URL(fileURLWithPath: destination))
            if let index = profiles.firstIndex(where: { $0.id == profileID }) {
                profiles[index].iconPath = destination
                persistProfiles()
            }
            commandOutput = "TheGamesDB · cover set for “\(match.title)” → \(destination)"
            lastResult = "Cover set from TheGamesDB"
        } catch {
            commandOutput = "TheGamesDB · \(error.localizedDescription)"
            lastResult = "Cover download failed"
        }
    }
}

@MainActor
private final class LauncherModel: ObservableObject {
    @Published var config = ToolkitConfig.load()
    @Published var profiles: [GameProfile]
    @Published var pathSettings: PathSettings
    @Published var driveMaps: [DriveMap]
    @Published var toolkitSourceFolder: String
    @Published var isRunning = false
    @Published var guidedSetupRunning = false
    @Published var awaitingGPTKDownload = false
    @Published var setupDeferred = false
    @Published var pendingSelection: SidebarSelection?
    @Published var liveProfileIDs: Set<UUID> = []
    /// macOS PIDs backing each live profile — used to terminate games directly.
    var liveProfilePIDs: [UUID: [Int32]] = [:]
    @Published var commandOutput = ""
    @Published var lastResult = "Ready"
    @Published var backups: [BackupItem] = []
    @Published var removeConfigOnUninstall = false
    @Published var removePrefixesOnUninstall = false
    @Published var showSetupGuide = false
    @Published var tgdbAPIKeyLocal: String = ""
    @Published var pinnedProfileIDs: [UUID] = []
    @Published var updateNotice: UpdateNotice?
    @Published var isCheckingForUpdates = false

    private let defaults = UserDefaults.standard
    private let setupGuideSeenKey = "setupGuideSeen.v2"
    private let tgdbAPIKeyDefaultsKey = "tgdbAPIKey"
    private let pinnedProfilesKey = "pinnedProfiles.v1"
    private var hasCheckedForUpdates = false
    private var openedGPTKPageForCurrentSetup = false

    var defaultSelection: SidebarSelection {
        .library
    }

    var statusLine: String {
        config.exists ? "Config loaded from \(config.configPath)" : "Config not found at \(config.configPath)"
    }

    var toolkitSourceReady: Bool {
        FileManager.default.isExecutableFile(atPath: "\(toolkitSourceFolder)/install.zsh")
    }

    var steamProfile: GameProfile {
        profiles.first(where: { $0.isSteamApp }) ?? GameProfile.steam(config: config)
    }

    var steamInstallerPath: String {
        config.steamSetupPath
    }

    var steamInstallerReady: Bool {
        FileManager.default.fileExists(atPath: steamInstallerPath)
    }

    var steamReady: Bool {
        steamExecutableExists(in: steamProfile)
    }

    var setupChecks: [SetupCheck] {
        [
            SetupCheck(
                id: "source",
                title: "Toolkit files",
                explanation: "RipperMoonKit's own helper scripts, copied onto your Mac.",
                detail: toolkitSourceFolder,
                isOK: toolkitSourceReady,
                isOptional: false
            ),
            SetupCheck(
                id: "scripts",
                title: "Game launchers",
                explanation: "The commands RipperMoonKit uses to start your games.",
                detail: "\(config.gptkLaunchPath) and \(config.gptkSteamPath)",
                isOK: config.hasToolkitScripts,
                isOptional: false
            ),
            SetupCheck(
                id: "config",
                title: "Settings file",
                explanation: "Your personal config — storage folders and launch options.",
                detail: config.configPath,
                isOK: config.exists,
                isOptional: false
            ),
            SetupCheck(
                id: "wine",
                title: "Game Porting Toolkit runner",
                explanation: "The prebuilt Wine/GPTK app runner copied into the local toolkit folder.",
                detail: config.localGPTKWineHome,
                isOK: config.hasLocalWineRunner,
                isOptional: false
            ),
            SetupCheck(
                id: "d3dmetal",
                title: "D3DMetal graphics",
                explanation: "Apple's official GPTK runtime layer that renders DirectX games on Metal.",
                detail: config.gptkRuntime,
                isOK: config.hasLocalD3DMetalRuntime,
                isOptional: false
            ),
            SetupCheck(
                id: "steamsetup",
                title: "Steam installer",
                explanation: "The downloaded Steam setup file — only needed if you use Steam.",
                detail: steamInstallerPath,
                isOK: steamInstallerReady,
                isOptional: true
            ),
            SetupCheck(
                id: "steam",
                title: "Windows Steam",
                explanation: "Steam installed in its game prefix. Optional — skip it for non-Steam games.",
                detail: steamExecutablePath(in: steamProfile),
                isOK: steamReady,
                isOptional: true
            )
        ]
    }

    var nextSetupActionTitle: String {
        if !toolkitSourceReady { return "Prepare Source" }
        if !config.hasToolkitScripts || !config.exists { return "Install Toolkit" }
        if !config.hasLocalGPTK { return "Begin GPTK Install" }
        if !steamInstallerReady { return "Download Steam" }
        if !steamReady { return "Install Steam" }
        return "Refresh Setup"
    }

    init() {
        let loaded = ToolkitConfig.load()
        config = loaded
        profiles = Self.loadProfiles(config: loaded, defaults: defaults)
        pathSettings = PathSettings(config: loaded)
        driveMaps = DriveMap.parse(loaded.values["GPTK_DRIVE_MAPS"] ?? "")
        let supportSource = Self.defaultToolkitSourceFolder(home: loaded.home)
        let desktopSource = "\(loaded.home)/Desktop/RipperMoonToolKit"
        if let storedSource = defaults.string(forKey: "toolkitSourceFolder") {
            let storedInstaller = "\(storedSource)/install.zsh"
            if storedSource == desktopSource && !FileManager.default.fileExists(atPath: storedInstaller) {
                toolkitSourceFolder = supportSource
            } else {
                toolkitSourceFolder = storedSource
            }
        } else {
            toolkitSourceFolder = supportSource
        }
        tgdbAPIKeyLocal = defaults.string(forKey: tgdbAPIKeyDefaultsKey)
            ?? (loaded.values["GPTK_TGDB_API_KEY"] ?? "")
        let validIDs = Set(profiles.map { $0.id })
        if let storedPins = defaults.array(forKey: pinnedProfilesKey) as? [String] {
            pinnedProfileIDs = storedPins.compactMap(UUID.init(uuidString:)).filter { validIDs.contains($0) }
        } else {
            // First run with pinning: seed with the first three profiles.
            pinnedProfileIDs = Array(profiles.prefix(3).map { $0.id })
        }
        refreshBackups()
        showSetupGuide = shouldShowSetupGuide(config: loaded)
        persistProfiles()
    }

    func reload() {
        persistProfiles()
        defaults.set(toolkitSourceFolder, forKey: "toolkitSourceFolder")
        config = ToolkitConfig.load()
        profiles = Self.repairProfiles(profiles, config: config)
        persistProfiles()
        pathSettings = PathSettings(config: config)
        driveMaps = DriveMap.parse(config.values["GPTK_DRIVE_MAPS"] ?? "")
        refreshBackups()
        guidedSetupRunning = false
        if config.hasLocalGPTK {
            awaitingGPTKDownload = false
            openedGPTKPageForCurrentSetup = false
        }
        // Surface the setup window when something is still missing; never
        // force it closed — if it is open and now complete it shows success.
        if (config.needsSetupGuide || !toolkitSourceReady) && !setupDeferred {
            showSetupGuide = true
        }
        lastResult = "Refreshed"
    }

    func profileBinding(id: UUID) -> Binding<GameProfile>? {
        guard profiles.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.profiles.first(where: { $0.id == id }) ?? GameProfile.empty(config: self.config) },
            set: { newValue in
                if let index = self.profiles.firstIndex(where: { $0.id == id }) {
                    self.profiles[index] = newValue
                    self.persistProfiles()
                }
            }
        )
    }

    func addProfile() -> GameProfile {
        let profile = GameProfile.empty(config: config)
        profiles.append(profile)
        persistProfiles()
        return profile
    }

    func deleteProfile(id: UUID) {
        if profiles.first(where: { $0.id == id })?.isRequiredLibraryProfile == true {
            lastResult = "Steam profile stays in the library"
            return
        }
        guard profiles.count > 1 else {
            lastResult = "At least one app profile is required"
            return
        }
        profiles.removeAll { $0.id == id }
        if pinnedProfileIDs.contains(id) {
            pinnedProfileIDs.removeAll { $0 == id }
            persistPins()
        }
        persistProfiles()
    }

    func persistProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: "gameProfiles.v1")
        }
    }

    func chooseFolder(current: String, assign: (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: current)
        if panel.runModal() == .OK, let url = panel.url {
            assign(url.path)
        }
    }

    func chooseExecutable(for profile: inout GameProfile) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: profile.gameFolder)
        if panel.runModal() == .OK, let url = panel.url {
            profile.gameFolder = url.deletingLastPathComponent().path
            profile.executable = url.lastPathComponent
            persistProfiles()
        }
    }

    func chooseIcon(for profile: inout GameProfile) {
        let panel = NSOpenPanel()
        panel.title = "Choose Game Icon"
        panel.prompt = "Use Icon"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.icns, .png, .jpeg, .tiff, .heic]
        if let iconPath = profile.iconPath, !iconPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: iconPath).deletingLastPathComponent()
        } else {
            panel.directoryURL = URL(fileURLWithPath: profile.gameFolder)
        }
        if panel.runModal() == .OK, let url = panel.url {
            profile.iconPath = url.path
            persistProfiles()
        }
    }

    func fileExists(_ relativePath: String, in profile: GameProfile) -> Bool {
        guard !relativePath.isEmpty else { return false }
        let path = URL(fileURLWithPath: profile.gameFolder).appendingPathComponent(relativePath).path
        return FileManager.default.fileExists(atPath: path)
    }

    func prefixPath(for profile: GameProfile) -> String {
        if profile.prefix.hasPrefix("/") || profile.prefix.hasPrefix("./") || profile.prefix.hasPrefix("../") {
            return NSString(string: profile.prefix).expandingTildeInPath
        }
        return "\(config.prefixRoot)/\(profile.prefix)"
    }

    func steamExecutableExists(in profile: GameProfile) -> Bool {
        FileManager.default.fileExists(atPath: steamExecutablePath(in: profile))
    }

    func steamExecutablePath(in profile: GameProfile) -> String {
        "\(prefixPath(for: profile))/drive_c/Program Files (x86)/Steam/steam.exe"
    }

    func startSteam(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        guard ensureSteamReady(for: profile) else { return }
        runShell(
            title: "Start Steam",
            command: previewStartSteamCommand(for: profile, detached: true),
            detached: true
        )
    }

    func installSpacewarFromSteam(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        guard ensureSteamReady(for: profile) else { return }
        runShell(
            title: "Install Spacewar AppID 480",
            command: previewInstallSpacewarCommand(for: profile, detached: true),
            detached: true
        )
    }

    func stopSteam() {
        runShell(title: "Stop Steam", command: previewStopSteamCommand())
    }

    func closeGame(_ profile: GameProfile) {
        // Prefer killing the actual macOS process tree the live poller found — a
        // Wine `taskkill` round-trip through gptk-launch is slow and unreliable.
        if let pids = liveProfilePIDs[profile.id], !pids.isEmpty {
            let list = pids.map(String.init).joined(separator: " ")
            liveProfileIDs.remove(profile.id)          // instant UI feedback
            liveProfilePIDs[profile.id] = nil
            runShell(
                title: "Close \(profile.name)",
                command: "kill \(list) 2>/dev/null; sleep 1; kill -9 \(list) 2>/dev/null; true"
            )
        } else {
            let repaired = repairedProfile(profile)
            runShell(title: "Close \(repaired.name)", command: previewCloseGameCommand(for: repaired))
        }
    }

    func launch(_ profile: GameProfile) {
        let profile = repairedProfile(profile)
        if (profile.requiresSteam || profile.isSteamManaged), !ensureSteamReady(for: profile) {
            return
        }
        runShell(
            title: "Launch \(profile.name)",
            command: launchCommand(for: profile, detached: true),
            detached: true
        )
    }

    func launchModEngine(_ profile: GameProfile) {
        let profile = repairedProfile(profile)
        if profile.requiresSteam, !ensureSteamReady(for: profile) {
            return
        }
        runShell(
            title: "Launch \(profile.name) ModEngine",
            command: previewModEngineLaunchCommand(for: profile, detached: true),
            detached: true
        )
    }

    func runRandomizer(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        runShell(
            title: "Run Randomizer",
            command: previewRandomizerCommand(for: profile, detached: true),
            detached: true
        )
    }

    func installModEngineRandomizerProfile(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        let sourceScript = "\(toolkitSourceFolder)/scripts/install-elden-mod-pack.zsh"
        let installedScript = "\(config.gptkHome)/scripts/install-elden-mod-pack.zsh"
        let toolsPrefix = toolPrefixName(for: profile)
        let toolEnv = toolRunnerEnvAssignment()
        runShell(
            title: "Install ModEngine + Randomizer",
            command: "\(sourceConfig); env \(toolEnv) \(config.gptkDotNet6Path.shellQuoted) --prefix \(toolsPrefix.shellQuoted); if [[ -x \(sourceScript.shellQuoted) ]]; then script=\(sourceScript.shellQuoted); else script=\(installedScript.shellQuoted); fi; zsh \"$script\" --game-dir \(profile.gameFolder.shellQuoted) --open-download-pages",
            completion: { [weak self] in self?.reload() }
        )
    }

    func backupEldenModState(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        let sourceScript = "\(toolkitSourceFolder)/scripts/elden-mod-state.zsh"
        let installedScript = "\(config.gptkHome)/scripts/elden-mod-state.zsh"
        runShell(
            title: "Backup Elden Ring Mod State",
            command: "\(sourceConfig); if [[ -x \(sourceScript.shellQuoted) ]]; then script=\(sourceScript.shellQuoted); else script=\(installedScript.shellQuoted); fi; zsh \"$script\" backup --game-dir \(profile.gameFolder.shellQuoted)"
        )
    }

    func importFriendKit(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        let panel = NSOpenPanel()
        panel.title = "Choose Friend Kit Folder Or ZIP"
        panel.prompt = "Import Friend Kit"
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "zip") ?? .zip]
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let sourceScript = "\(toolkitSourceFolder)/scripts/elden-mod-state.zsh"
        let installedScript = "\(config.gptkHome)/scripts/elden-mod-state.zsh"
        let toolsPrefix = toolPrefixName(for: profile)
        let toolEnv = toolRunnerEnvAssignment()
        runShell(
            title: "Import Friend Kit",
            command: "\(sourceConfig); env \(toolEnv) \(config.gptkDotNet6Path.shellQuoted) --prefix \(toolsPrefix.shellQuoted); if [[ -x \(sourceScript.shellQuoted) ]]; then script=\(sourceScript.shellQuoted); else script=\(installedScript.shellQuoted); fi; zsh \"$script\" import-friend --game-dir \(profile.gameFolder.shellQuoted) --friend-kit \(url.path.shellQuoted) --force",
            completion: { [weak self] in self?.reload() }
        )
    }

    func installModZips(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        let panel = NSOpenPanel()
        panel.title = "Choose ModEngine, Randomizer, Seamless Coop, Or Anti Cheat ZIPs"
        panel.prompt = "Install Zips"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [UTType(filenameExtension: "zip") ?? .zip]
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        guard panel.runModal() == .OK else { return }
        let paths = panel.urls.map(\.path)
        guard !paths.isEmpty else { return }

        runShell(
            title: "Install Mod Zips",
            command: modZipInstallCommand(for: profile, zipPaths: paths)
        )
    }

    func prepareModEngine(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        do {
            let modEngineDir = modEngineDirectory(for: profile)
            try FileManager.default.createDirectory(atPath: modEngineDir, withIntermediateDirectories: true)
            try writeModEngineConfig(for: profile)
            try writeModEngineLaunchBat(for: profile)
            lastResult = "Prepared ModEngine files"
            commandOutput = """
            Wrote:
            \(modEngineConfigPath(for: profile))
            \(modEngineLaunchBatPath(for: profile))

            Open the randomizer, import the .randomizeopt file, click Randomize, then launch the modded profile.
            """
        } catch {
            lastResult = "ModEngine prep failed"
            commandOutput = error.localizedDescription
        }
    }

    func installVCRuntime(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        runShell(
            title: "Install VC++ Runtime",
            command: "\(sourceConfig); \(config.gptkVCRunPath.shellQuoted) --prefix \(profile.prefix.shellQuoted)"
        )
    }

    func installDotNet6(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        runShell(
            title: "Install .NET 6 Desktop Runtime",
            command: "\(sourceConfig); \(config.gptkDotNet6Path.shellQuoted) --prefix \(profile.prefix.shellQuoted)"
        )
    }

    func installVCRuntimeGlobally() {
        runShell(
            title: "Install VC++ Runtime",
            command: "\(sourceConfig); \(config.gptkVCRunPath.shellQuoted) --all"
        )
    }

    func installStubs(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        runShell(
            title: "Install API Stubs",
            command: "\(sourceConfig); \(config.gptkStubsPath.shellQuoted) --prefix \(profile.prefix.shellQuoted)"
        )
    }

    func installStubsGlobally() {
        runShell(
            title: "Install API Stubs",
            command: "\(sourceConfig); \(config.gptkStubsPath.shellQuoted) --all"
        )
    }

    func createBackupOnly() {
        runShell(
            title: "Create Backup",
            command: "\(toolkitSourceBootstrapCommand)\n./install.zsh --skip-deps --backup-only",
            completion: { [weak self] in self?.refreshBackups() }
        )
    }

    func installToolkit() {
        runShell(
            title: "Install Toolkit",
            command: "\(toolkitSourceBootstrapCommand)\n./install.zsh --skip-deps",
            completion: { [weak self] in self?.refreshBackups() }
        )
    }

    func installDependencies() {
        let work = """
        echo "Installing dependencies and Apple Game Porting Toolkit 3.0…"
        echo "macOS may ask for your Mac password once (to install Homebrew)."
        echo "Copying GPTK can take several minutes with no output — that is normal."
        echo

        \(toolkitSourceBootstrapCommand)
        set +e

        RIPPERMOON_OPEN_GPTK_PAGE=0 ./install.zsh
        """
        runScriptInTerminal(named: "install-gptk", title: "Install GPTK", work: work)
    }

    func beginGPTKInstall() {
        refreshSetupChecks()
        guard config.hasLocalGPTK || config.hasGPTKInstallMedia else {
            showGPTKDownloadStep(openBrowser: false)
            return
        }
        awaitingGPTKDownload = false
        installDependencies()
    }

    func runNextSetupStep() {
        if !toolkitSourceReady {
            prepareToolkitSource()
        } else if !config.hasToolkitScripts || !config.exists {
            installToolkit()
        } else if !config.hasLocalGPTK {
            config.hasGPTKInstallMedia ? beginGPTKInstall() : showGPTKDownloadStep(openBrowser: true)
        } else if !steamInstallerReady {
            downloadSteamInstaller()
        } else if !steamReady {
            installSteam()
        } else {
            reload()
            commandOutput = setupChecks.map { "\($0.isOK ? "✅" : "❌") \($0.title): \($0.detail)" }.joined(separator: "\n")
        }
    }

    func startFirstRunSetup() {
        refreshSetupChecks()
        if !config.hasLocalGPTK && !config.hasGPTKInstallMedia {
            showGPTKDownloadStep(openBrowser: true)
            return
        }
        awaitingGPTKDownload = false
        runFirstRunSetup()
    }

    func runFirstRunSetup() {
        refreshSetupChecks()
        if !config.hasLocalGPTK && !config.hasGPTKInstallMedia {
            showGPTKDownloadStep(openBrowser: true)
            return
        }
        awaitingGPTKDownload = false

        let work = """
        echo "════════ RipperMoonKit — First Run Setup ════════"
        echo
        echo "This installs everything RipperMoonKit needs to run games."
        echo
        echo "  • macOS may ask for your Mac password once (to install Homebrew)."
        echo "  • Some steps copy several GB and show no output while copying."
        echo "    That is normal — leave this window open until you see the"
        echo "    SETUP FINISHED banner at the bottom."
        echo

        \(toolkitSourceBootstrapCommand)
        set +e

        echo
        echo "➡️  Step 1 of 3 — installing toolkit scripts and local config…"
        setup_status=0
        ./install.zsh --skip-deps || {
          setup_status=$?
          echo "⚠️  Toolkit step had problems — see the output above."
        }

        echo
        echo "➡️  Step 2 of 3 — dependencies + Apple Game Porting Toolkit 3.0…"
        echo "    If GPTK is missing, download Game Porting Toolkit 3.0 from Apple,"
        echo "    open the downloaded DMG so it mounts, then let this window continue."
        echo "    Copying GPTK can take several minutes with no output."
        RIPPERMOON_OPEN_GPTK_PAGE=1 ./install.zsh || {
          setup_status=$?
          echo "⚠️  GPTK 3.0 is not installed yet."
          echo "    Download Game Porting Toolkit 3.0, mount the DMG, then run setup again."
        }

        echo
        echo "➡️  Step 3 of 3 — installing Windows Steam…"
        if [[ "$setup_status" -eq 0 ]]; then
          ./install.zsh --install-steam || echo "⚠️  Steam step incomplete — install it later from the Steam profile."
        else
          echo "⏭️  Skipping Steam until the required toolkit pieces are installed."
        fi

        exit "$setup_status"
        """
        runScriptInTerminal(named: "guided-setup", title: "Guided Setup", work: work)
    }

    func prepareToolkitSource() {
        runShell(
            title: "Prepare Source",
            command: toolkitSourceBootstrapCommand,
            completion: { [weak self] in self?.reload() }
        )
    }

    func downloadSteamInstaller() {
        runShell(
            title: "Download Steam Installer",
            command: "\(toolkitSourceBootstrapCommand)\n./install.zsh --no-homebrew-bootstrap --skip-gptk",
            completion: { [weak self] in self?.reload() }
        )
    }

    func installSteam() {
        runShell(
            title: steamReady ? "Repair Steam Install" : "Install Steam",
            command: "\(toolkitSourceBootstrapCommand)\n./install.zsh --no-homebrew-bootstrap --skip-gptk --install-steam",
            completion: { [weak self] in self?.reload() }
        )
    }

    private func ensureSteamReady(for profile: GameProfile) -> Bool {
        let steam = profile.isSteamApp ? profile : steamProfile
        guard steamExecutableExists(in: steam) else {
            lastResult = "Steam install required"
            commandOutput = """
            Windows Steam is not ready for \(profile.name).

            Missing:
            \(steamExecutablePath(in: steam))

            Use the Steam profile's Install Steam / Repair Steam button, or run Set Up RipperMoonKit.
            """
            showSetupGuide = true
            return false
        }
        return true
    }

    func checkForAvailableUpdate(force: Bool = false) async {
        if isCheckingForUpdates || (!force && hasCheckedForUpdates) {
            return
        }

        isCheckingForUpdates = true
        hasCheckedForUpdates = true
        defer { isCheckingForUpdates = false }

        guard let url = URL(string: "https://api.github.com/repos/MoonTheRipper/RipperMoonKit/releases/latest") else {
            return
        }

        do {
            var request = URLRequest(url: url, timeoutInterval: 8)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("RipperMoonKit/\(rmkAppVersion)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                if force {
                    lastResult = "Update check failed"
                    commandOutput = "GitHub did not return the latest release information.\n"
                }
                return
            }

            let release = try JSONDecoder().decode(GitHubReleaseInfo.self, from: data)
            let releaseURL = release.htmlURL ?? URL(string: "https://github.com/MoonTheRipper/RipperMoonKit/releases/latest")!
            if Self.isVersion(release.tagName, newerThan: rmkAppVersion) {
                updateNotice = UpdateNotice(version: release.tagName, url: releaseURL)
                if force {
                    lastResult = "Update available"
                    commandOutput = "RipperMoonKit \(release.tagName) is available. Open Settings > Maintenance > Update From GitHub.\n"
                }
            } else {
                updateNotice = nil
                if force {
                    lastResult = "Already on latest release"
                    commandOutput = "Installed version: \(rmkAppVersion)\nLatest GitHub release: \(release.tagName)\n"
                }
            }
        } catch {
            if force {
                lastResult = "Update check failed"
                commandOutput = "\(error.localizedDescription)\n"
            }
        }
    }

    func updateFromGitHub() {
        let command = """
        \(toolkitSourceBootstrapCommand)
        if [[ -d .git ]]; then
          git fetch --tags origin && \
          if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then git pull --ff-only origin main; else echo "Already up to date."; fi
        else
          echo "Toolkit source exists without Git metadata; using installed source as-is."
        fi
        ./install.zsh --skip-deps && \
        zsh scripts/install-gui-app.zsh
        """
        runShell(
            title: "Update From GitHub",
            command: command,
            completion: { [weak self] in self?.reload() },
            successCompletion: { [weak self] in self?.relaunchAfterUpdate() }
        )
    }

    func uninstallToolkit() {
        var args: [String] = []
        if removeConfigOnUninstall {
            args.append("--remove-config")
        }
        if removePrefixesOnUninstall {
            args.append("--remove-prefixes")
        }

        runShell(
            title: "Uninstall Toolkit",
            command: "\(toolkitSourceBootstrapCommand)\nzsh scripts/uninstall.zsh \(args.joined(separator: " "))",
            completion: { [weak self] in self?.reload() }
        )
    }

    func rollbackBackup(id: BackupItem.ID) {
        guard let backup = backups.first(where: { $0.id == id }) else { return }
        runShell(
            title: "Rollback",
            command: "\(toolkitSourceBootstrapCommand)\n./install.zsh --rollback \(backup.name.shellQuoted)",
            completion: { [weak self] in self?.refreshBackups() }
        )
    }

    func refreshBackups() {
        let backupRoot = URL(fileURLWithPath: config.gptkHome).appendingPathComponent("backups")
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: backupRoot,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        backups = contents
            .filter { $0.lastPathComponent.hasPrefix("rippermoon-update-") }
            .map { url in
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return BackupItem(name: url.lastPathComponent, path: url.path, modified: modified)
            }
            .sorted { $0.modified > $1.modified }
    }

    func openLogsFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: config.logsPath))
    }

    func reportTestResult(for profile: GameProfile?) {
        let report = testerReportMarkdown(for: profile)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)

        var components = URLComponents(string: "https://github.com/MoonTheRipper/RipperMoonKit/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: "Game test report: \(profile?.name ?? "New game")"),
            URLQueryItem(name: "body", value: report)
        ]

        if let url = components?.url {
            NSWorkspace.shared.open(url)
            lastResult = "Tester report copied"
            commandOutput = "A structured tester report was copied to the clipboard and opened in GitHub Issues. GitHub may still ask the tester to sign in before submitting."
        } else {
            lastResult = "Tester report copied"
            commandOutput = report
        }
    }

    func openGPTKPage() {
        NSWorkspace.shared.open(URL(string: config.gptkDownloadPage)!)
    }

    func showGPTKDownloadStep(openBrowser: Bool) {
        guidedSetupRunning = false
        awaitingGPTKDownload = true
        showSetupGuide = true
        lastResult = "Download GPTK 3.0"
        commandOutput = """
        Download Game Porting Toolkit 3.0 from Apple Developer.

        Open the downloaded DMG so it appears in Finder, then return to RipperMoonKit and click Begin GPTK Install.
        """
        if openBrowser {
            openGPTKPageForCurrentSetupIfNeeded()
        }
    }

    func openGPTKPageForCurrentSetupIfNeeded() {
        guard awaitingGPTKDownload, !openedGPTKPageForCurrentSetup else { return }
        openedGPTKPageForCurrentSetup = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, self.awaitingGPTKDownload else { return }
            self.openGPTKPage()
        }
    }

    /// Opens the documentation bundled inside the app (offline-safe), falling
    /// back to the GitHub repository if the bundled docs are not present.
    func openHelpDocs(page: String = "index.html") {
        let local = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/docs", isDirectory: true)
            .appendingPathComponent(page)
        if FileManager.default.fileExists(atPath: local.path) {
            NSWorkspace.shared.open(local)
        } else {
            NSWorkspace.shared.open(URL(string: "https://github.com/MoonTheRipper/RipperMoonKit")!)
        }
    }

    func dismissSetupGuide() {
        showSetupGuide = false
    }

    /// "Set up later" — closes the window for this session. The persistent
    /// Finish Setup banner stays visible so the user can resume any time.
    func deferSetup() {
        setupDeferred = true
        awaitingGPTKDownload = false
        showSetupGuide = false
    }

    /// Reopens the setup window from the Finish Setup banner.
    func reopenSetupGuide() {
        setupDeferred = false
        config = ToolkitConfig.load()
        showSetupGuide = true
    }

    /// "Start Gaming" — leaves the finished setup window for the library.
    func finishSetup() {
        showSetupGuide = false
        pendingSelection = .library
    }

    /// Optional next step — jump into Settings for game folder / cover art.
    func openSetupRelatedSettings() {
        showSetupGuide = false
        pendingSelection = .settings
    }

    /// Optional next step — open the Steam app to finish installing Steam.
    func goToSteamSetup() {
        showSetupGuide = false
        pendingSelection = .profile(steamProfile.id)
    }

    /// Lightweight re-read so the setup checklist ticks itself off live.
    func refreshSetupChecks() {
        config = ToolkitConfig.load()
    }

    private func shouldShowSetupGuide(config: ToolkitConfig) -> Bool {
        !setupDeferred && (config.needsSetupGuide || !toolkitSourceReady)
    }

    private func testerReportMarkdown(for profile: GameProfile?) -> String {
        let p = profile ?? profiles.first(where: { !$0.isSteamApp })
        let name = p?.name ?? "New game"
        let executable = p?.executable ?? ""
        let prefix = p?.prefix ?? ""
        let runner = redactedPath(p?.runnerPath ?? "")
        let folder = redactedPath(p?.gameFolder ?? "")
        let modEngine = p?.useModEngine == true ? "enabled" : "disabled"
        let steam = p?.requiresSteam == true || p?.isSteamManaged == true ? "yes" : "no"

        return """
        ## Tester Report

        ### Game
        - Name: \(name)
        - Executable: \(executable.isEmpty ? "unknown" : executable)
        - Result: launched / playable / crash / black screen / freeze / other

        ### Profile
        - Prefix: \(prefix.isEmpty ? "unknown" : prefix)
        - Requires Steam: \(steam)
        - ModEngine: \(modEngine)
        - Winver: \(p?.winver ?? "unknown")
        - No DXR: \(p?.noDXR == true ? "yes" : "no")
        - No esync: \(p?.noEsync == true ? "yes" : "no")
        - MetalFX: \(p?.metalFX == true ? "yes" : "no")
        - HUD: \(p?.hud == true ? "yes" : "no")
        - Runner: \(runner.isEmpty ? "default" : runner)
        - Game folder: \(folder.isEmpty ? "not set" : folder)

        ### Machine
        - macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        - Architecture: \(machineArchitecture)
        - RipperMoonKit: \(rmkAppVersion)

        ### What happened?
        Describe the launch result, what screen appeared, and whether sound/input/networking worked.

        ### Steps tried
        1.
        2.
        3.

        ### Expected result
        What should have happened?

        ### Actual result
        What happened instead?

        ### Useful log lines
        Paste only the relevant lines from \(redactedPath(config.logsPath)).
        """
    }

    private func redactedPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        guard !path.isEmpty else { return path }
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~/" + path.dropFirst(home.count + 1)
        }
        return path
    }

    private var machineArchitecture: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }

    func addDriveMap() {
        let used = Set(driveMaps.map { $0.letter.uppercased() })
        let letter = (["D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "T", "U", "V", "W", "Y", "Z"].first { !used.contains($0) }) ?? "D"
        driveMaps.append(DriveMap(letter: letter, path: config.externalRoot))
    }

    func removeDriveMap(id: UUID) {
        driveMaps.removeAll { $0.id == id }
    }

    func savePathSettings() {
        defaults.set(toolkitSourceFolder, forKey: "toolkitSourceFolder")
        saveEnvValues([
            "GPTK_HOME": envPath(pathSettings.gptkHome),
            "GPTK_PREFIX_ROOT": envPath(pathSettings.prefixRoot),
            "GPTK_GAMES_ROOT": envPath(pathSettings.gamesRoot),
            "GPTK_EXTERNAL_ROOT": envPath(pathSettings.externalRoot),
            "GPTK_STEAM_LIBRARY": envPath(pathSettings.steamLibrary)
        ])
    }

    func saveDriveMaps() {
        var seen = Set<String>()
        var parts: [String] = []

        for map in driveMaps {
            let letter = map.letter.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let path = map.path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard letter.count == 1, letter != "C", !path.isEmpty, !seen.contains(letter) else {
                continue
            }
            seen.insert(letter)
            parts.append("\(letter)=\(envPath(path))")
        }

        driveMaps = parts.compactMap { DriveMap(line: $0) }
        saveEnvValues(["GPTK_DRIVE_MAPS": parts.joined(separator: ";")])
    }

    func previewStartSteamCommand(for profile: GameProfile, detached: Bool = false) -> String {
        let writeState = steamStateWriteCommand(for: profile)
        if detached {
            return "\(sourceConfig); \(writeState); \(steamStartDetachedCommand(for: profile))"
        }
        let envPart = steamEnvAssignment(for: profile)
        return "\(sourceConfig); \(writeState); env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log"
    }

    func previewInstallSpacewarCommand(for profile: GameProfile, detached: Bool = false) -> String {
        let writeState = steamStateWriteCommand(for: profile)
        let envPart = steamEnvAssignment(for: profile)
        let logPath = "\(config.logsPath)/steam-spacewar-480.log"
        if detached {
            return "\(sourceConfig); \(writeState); nohup env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log --install-spacewar >> \(logPath.shellQuoted) 2>&1 &"
        }
        return "\(sourceConfig); \(writeState); env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log --install-spacewar"
    }

    func previewInstallSteamCommand() -> String {
        "\(toolkitSourceBootstrapCommand)\n./install.zsh --no-homebrew-bootstrap --skip-gptk --install-steam"
    }

    func previewStopSteamCommand() -> String {
        "\(sourceConfig); \(config.gptkSteamPath.shellQuoted) --kill"
    }

    private func steamStatePath(for profile: GameProfile) -> String {
        "\(config.gptkHome)/state/steam-\(profile.prefix.safeShellIdentifier).env"
    }

    private func steamStateWriteCommand(for profile: GameProfile) -> String {
        let statePath = steamStatePath(for: profile)
        let stateDir = (statePath as NSString).deletingLastPathComponent
        let lines = [
            "prefix=\(profile.prefix)",
            "runner=\(profile.runnerPath)",
            "noEsync=\(profile.noEsync ? "1" : "0")",
            "updatedAt=\(ISO8601DateFormatter().string(from: Date()))"
        ]
        let payload = lines.map(\.shellQuoted).joined(separator: " ")
        return "mkdir -p \(stateDir.shellQuoted); printf '%s\\n' \(payload) > \(statePath.shellQuoted)"
    }

    private func steamStartDetachedCommand(for profile: GameProfile) -> String {
        let logPath = "\(config.logsPath)/\(profile.safeName)-steam.log"
        let envPart = steamEnvAssignment(for: profile)
        return "nohup env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log >> \(logPath.shellQuoted) 2>&1 &"
    }

    private func steamWaitForUICommand(timeout: Int = 45) -> String {
        """
        steam_ready=0; \
        for i in {1..\(timeout)}; do \
          if ps -axww -o command= | grep -qi '[s]teamwebhelper.exe'; then steam_ready=1; break; fi; \
          sleep 1; \
        done; \
        if [[ "$steam_ready" != "1" ]]; then \
          echo "RipperMoonKit: Steam did not finish bringing up its UI within \(timeout) seconds. Launch Steam from this profile first, wait for the library window, then launch again."; \
          exit 74; \
        fi
        """
    }

    private func steamDependencyPreflightCommand(for profile: GameProfile) -> String {
        guard profile.requiresSteam && !profile.isSteamManaged else { return "" }

        let expectedRunner = profile.runnerPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let statePath = steamStatePath(for: profile)
        let noEsync = profile.noEsync ? "1" : "0"
        let startSteam = "\(steamStateWriteCommand(for: profile)); \(steamStartDetachedCommand(for: profile))"
        let waitForSteam = steamWaitForUICommand()

        return """
        steam_lines="$(ps -axww -o command= | grep -i '[s]team.exe' || true)"; \
        if [[ -n "$steam_lines" ]]; then \
          if [[ -n \(expectedRunner.shellQuoted) ]] && ! print -r -- "$steam_lines" | grep -Fq \(expectedRunner.shellQuoted); then \
            echo "RipperMoonKit: Steam is already running with a different Wine runner. Close Steam, then use this profile's Start Steam button before launching."; \
            exit 72; \
          fi; \
          if [[ \(noEsync.shellQuoted) == "1" ]] && { [[ ! -r \(statePath.shellQuoted) ]] || ! grep -Fq 'noEsync=1' \(statePath.shellQuoted); }; then \
            echo "RipperMoonKit: Steam is already running without this profile's no-esync startup marker. Close Steam, then use this profile's Start Steam button before launching."; \
            exit 73; \
          fi; \
        else \
          \(startSteam); \
        fi; \
        \(waitForSteam)
        """
    }

    func previewSteamManagedLaunchCommand(for profile: GameProfile, detached: Bool = false) -> String {
        let logPath = "\(config.logsPath)/\(profile.safeName).log"
        let appLaunch = (profile.steamAppID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let appArgs = appLaunch.isEmpty ? "" : " -applaunch \(appLaunch.shellQuoted)"
        let envPart = steamEnvAssignment(for: profile)
        let launch = "nohup env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log\(appArgs) >> \(logPath.shellQuoted) 2>&1 &"

        if detached {
            return "\(sourceConfig); \(launch)"
        }
        return "\(sourceConfig); env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log\(appArgs)"
    }

    func launchCommand(for profile: GameProfile, detached: Bool = false) -> String {
        if profile.isSteamManaged {
            return previewSteamManagedLaunchCommand(for: profile, detached: detached)
        }
        if profile.useModEngine == true {
            return previewModEngineLaunchCommand(for: profile, detached: detached)
        }
        return previewLaunchCommand(for: profile, detached: detached)
    }

    func previewCloseGameCommand(for profile: GameProfile) -> String {
        let commands = closeTargets(for: profile).map { target in
            "env \(runnerEnvAssignment(for: profile)) \(config.gptkLaunchPath.shellQuoted) --prefix \(profile.prefix.shellQuoted) --no-log -- taskkill /IM \(target.shellQuoted) /F >/dev/null 2>&1 || true"
        }
        if commands.isEmpty {
            return "\(sourceConfig); echo \("No process target configured for \(profile.name)".shellQuoted)"
        }
        return "\(sourceConfig); \(commands.joined(separator: "; "))"
    }

    func previewLaunchCommand(for profile: GameProfile, detached: Bool = false) -> String {
        let logPath = "\(config.logsPath)/\(profile.safeName).log"
        var args: [String] = ["--prefix", profile.prefix, "--set-winver", profile.winver]
        if profile.noDXR { args.append("--no-dxr") }
        if profile.avx == true { args.append("--avx") }
        if profile.noEsync { args.append("--no-esync") }
        if profile.metalFX == true { args.append("--metalfx") }
        if profile.hud { args.append("--hud") }
        args.append(contentsOf: ["--log-file", logPath, "--", "./\(profile.executable)"])

        let extra = profile.extraArguments.trimmingCharacters(in: .whitespacesAndNewlines)
        let extraPart = extra.isEmpty ? "" : " \(extra)"
        let overrides = dllOverrides(for: profile)
        let launch = "cd \(profile.gameFolder.shellQuoted) && nohup env \(runnerEnvAssignment(for: profile)) WINEDLLOVERRIDES=\(overrides.shellQuoted) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " "))\(extraPart) >> \(logPath.shellQuoted) 2>&1 &"
        let preflight = steamDependencyPreflightCommand(for: profile)
        let detachedLaunch = [preflight, launch].filter { !$0.isEmpty }.joined(separator: "; ")

        if detached {
            return "\(sourceConfig); \(detachedLaunch)"
        }
        let foregroundLaunch = "cd \(profile.gameFolder.shellQuoted) && env \(runnerEnvAssignment(for: profile)) WINEDLLOVERRIDES=\(overrides.shellQuoted) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " "))\(extraPart)"
        return "\(sourceConfig); \([preflight, foregroundLaunch].filter { !$0.isEmpty }.joined(separator: "; "))"
    }

    func previewModEngineLaunchCommand(for profile: GameProfile, detached: Bool = false) -> String {
        let logPath = "\(config.logsPath)/\(profile.safeName)-modengine.log"
        let modEngineDir = modEngineDirectory(for: profile)
        var args: [String] = ["--prefix", profile.prefix, "--set-winver", profile.winver]
        if profile.noDXR { args.append("--no-dxr") }
        if profile.avx == true { args.append("--avx") }
        if profile.noEsync { args.append("--no-esync") }
        if profile.metalFX == true { args.append("--metalfx") }
        if profile.hud { args.append("--hud") }
        args.append(contentsOf: [
            "--log-file", logPath,
            "--",
            "./\(profile.modEngineLauncherName)",
            "-t", "er",
            "-c", "./\(profile.modEngineConfigName)",
            "--game-path", winePath(forMacPath: "\(profile.gameFolder)/eldenring.exe")
        ])

        let overrides = dllOverrides(for: profile)
        let launch = "cd \(modEngineDir.shellQuoted) && nohup env \(runnerEnvAssignment(for: profile)) WINEDLLOVERRIDES=\(overrides.shellQuoted) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " ")) >> \(logPath.shellQuoted) 2>&1 &"
        let preflight = steamDependencyPreflightCommand(for: profile)
        let detachedLaunch = [preflight, launch].filter { !$0.isEmpty }.joined(separator: "; ")

        if detached {
            return "\(sourceConfig); \(detachedLaunch)"
        }
        let foregroundLaunch = "cd \(modEngineDir.shellQuoted) && env \(runnerEnvAssignment(for: profile)) WINEDLLOVERRIDES=\(overrides.shellQuoted) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " "))"
        return "\(sourceConfig); \([preflight, foregroundLaunch].filter { !$0.isEmpty }.joined(separator: "; "))"
    }

    func previewRandomizerCommand(for profile: GameProfile, detached: Bool = false) -> String {
        let logPath = "\(config.logsPath)/\(profile.safeName)-randomizer.log"
        let modEngineDir = modEngineDirectory(for: profile)
        let randomizerRelative = profile.randomizerExecutablePath
        let randomizerDir = URL(fileURLWithPath: modEngineDir).appendingPathComponent(randomizerRelative).deletingLastPathComponent().path
        var args: [String] = ["--prefix", toolPrefixName(for: profile), "--set-winver", profile.winver, "--no-esync", "--no-dxr"]
        args.append(contentsOf: ["--log-file", logPath, "--", "./\((randomizerRelative as NSString).lastPathComponent)"])
        let toolEnv = toolRunnerEnvAssignment()

        let launch = "cd \(randomizerDir.shellQuoted) && nohup env \(toolEnv) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " ")) >> \(logPath.shellQuoted) 2>&1 &"
        if detached {
            return "\(sourceConfig); \(launch)"
        }
        return "\(sourceConfig); cd \(randomizerDir.shellQuoted) && env \(toolEnv) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " "))"
    }

    func modZipInstallCommand(for profile: GameProfile, zipPaths: [String]) -> String {
        let zipList = zipPaths.map(\.shellQuoted).joined(separator: " ")
        return """
        \(sourceConfig)
        game=\(profile.gameFolder.shellQuoted)
        modengine=\(modEngineDirectory(for: profile).shellQuoted)
        stamp="$(date +%Y%m%d-%H%M%S)"
        cleanup_mac_sidecars() {
          local path="$1"
          [[ -d "$path" ]] || return 0
          find "$path" \\( -name '._*' -o -name '.DS_Store' -o -name '__MACOSX' \\) -exec rm -rf {} + 2>/dev/null || true
        }
        mkdir -p "$modengine"
        for zip in \(zipList); do
          echo "Inspecting $zip"
          entries="$(unzip -Z1 "$zip" 2>/dev/null || true)"
          if print -r -- "$entries" | grep -qi 'modengine2_launcher.exe'; then
            echo "Installing ModEngine 2"
            unzip -oq "$zip" -d "$modengine"
            cleanup_mac_sidecars "$modengine"
            if [[ ! -f "$modengine/modengine2_launcher.exe" ]]; then
              root="$(find "$modengine" -mindepth 1 -maxdepth 1 -type d -print | head -n 1)"
              if [[ -n "$root" && -f "$root/modengine2_launcher.exe" ]]; then
                find "$root" -mindepth 1 -maxdepth 1 -exec mv -f {} "$modengine/" \\;
                rmdir "$root" 2>/dev/null || true
              fi
            fi
            cleanup_mac_sidecars "$modengine"
          elif print -r -- "$entries" | grep -qi 'EldenRingRandomizer.exe'; then
            echo "Installing Item and Enemy Randomizer"
            target="$modengine/randomizer"
            tmp="$modengine/.randomizer-install-$stamp"
            [[ -d "$target" ]] && mv "$target" "$target.$stamp.backup"
            rm -rf "$tmp"
            mkdir -p "$tmp"
            unzip -oq "$zip" -d "$tmp"
            cleanup_mac_sidecars "$tmp"
            root="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d -print | head -n 1)"
            if [[ -n "$root" && -f "$root/EldenRingRandomizer.exe" ]]; then
              mv "$root" "$target"
            else
              mkdir -p "$target"
              find "$tmp" -mindepth 1 -maxdepth 1 -exec mv -f {} "$target/" \\;
            fi
            rm -rf "$tmp"
            cleanup_mac_sidecars "$target"
          elif print -r -- "$entries" | grep -qi 'ersc_launcher.exe'; then
            echo "Installing Seamless Coop"
            keep="$(mktemp -t ersc-settings.XXXXXX)"
            [[ -f "$game/SeamlessCoop/ersc_settings.ini" ]] && cp "$game/SeamlessCoop/ersc_settings.ini" "$keep"
            unzip -oq "$zip" -d "$game"
            cleanup_mac_sidecars "$game/SeamlessCoop"
            [[ -s "$keep" ]] && mkdir -p "$game/SeamlessCoop" && cp "$keep" "$game/SeamlessCoop/ersc_settings.ini"
            rm -f "$keep"
          elif print -r -- "$entries" | grep -qi 'toggle_anti_cheat.exe'; then
            echo "Installing Anti Cheat Toggler"
            unzip -oq "$zip" -d "$game"
            cleanup_mac_sidecars "$game"
          else
            echo "Skipped unrecognized zip: $zip"
          fi
        done
        echo "Mod zip install finished."
        """
    }

    func modEngineValidationItems(for profile: GameProfile) -> [ValidationItem] {
        [
            ValidationItem(title: "eldenring.exe", isOK: FileManager.default.fileExists(atPath: "\(profile.gameFolder)/eldenring.exe")),
            ValidationItem(title: profile.modEngineLauncherName, isOK: FileManager.default.fileExists(atPath: modEngineLauncherPath(for: profile))),
            ValidationItem(title: profile.modEngineConfigName, isOK: FileManager.default.fileExists(atPath: modEngineConfigPath(for: profile))),
            ValidationItem(title: profile.modEngineLaunchBatName, isOK: FileManager.default.fileExists(atPath: modEngineLaunchBatPath(for: profile))),
            ValidationItem(title: profile.randomizerExecutablePath, isOK: FileManager.default.fileExists(atPath: randomizerExecutablePath(for: profile))),
            ValidationItem(title: profile.seamlessDllConfigPath, isOK: FileManager.default.fileExists(atPath: URL(fileURLWithPath: modEngineDirectory(for: profile)).appendingPathComponent(profile.seamlessDllConfigPath).standardized.path))
        ]
    }

    func modEngineDirectory(for profile: GameProfile) -> String {
        resolvedProfilePath(profile.modEngineFolderPath, in: profile.gameFolder)
    }

    func profileRelativePath(_ path: String, from gameFolder: String) -> String {
        let folder = URL(fileURLWithPath: gameFolder).standardized.path
        let selected = URL(fileURLWithPath: path).standardized.path
        if selected == folder {
            return "."
        }
        if selected.hasPrefix(folder + "/") {
            return String(selected.dropFirst(folder.count + 1))
        }
        return selected
    }

    private func modEngineLauncherPath(for profile: GameProfile) -> String {
        URL(fileURLWithPath: modEngineDirectory(for: profile)).appendingPathComponent(profile.modEngineLauncherName).path
    }

    private func modEngineConfigPath(for profile: GameProfile) -> String {
        URL(fileURLWithPath: modEngineDirectory(for: profile)).appendingPathComponent(profile.modEngineConfigName).path
    }

    private func modEngineLaunchBatPath(for profile: GameProfile) -> String {
        URL(fileURLWithPath: modEngineDirectory(for: profile)).appendingPathComponent(profile.modEngineLaunchBatName).path
    }

    private func randomizerExecutablePath(for profile: GameProfile) -> String {
        URL(fileURLWithPath: modEngineDirectory(for: profile)).appendingPathComponent(profile.randomizerExecutablePath).path
    }

    private func writeModEngineConfig(for profile: GameProfile) throws {
        let configPath = modEngineConfigPath(for: profile)
        try backupFileIfPresent(configPath)
        let text = """
        [modengine]
        debug = false

        external_dlls = [
            "\(profile.seamlessDllConfigPath.tomlEscaped)"
        ]

        [extension.mod_loader]
        enabled = true
        loose_params = false

        mods = [
            { enabled = true, name = "default", path = "mod" },
            { enabled = true, name = "randomizer", path = "randomizer" }
        ]

        [extension.scylla_hide]
        enabled = false
        """
        try text.write(toFile: configPath, atomically: true, encoding: .utf8)
    }

    private func writeModEngineLaunchBat(for profile: GameProfile) throws {
        let batPath = modEngineLaunchBatPath(for: profile)
        try backupFileIfPresent(batPath)
        let gameExe = winePath(forMacPath: "\(profile.gameFolder)/eldenring.exe")
        let text = """
        @echo off
        chcp 65001
        .\\\(profile.modEngineLauncherName) -t er -c .\\\(profile.modEngineConfigName) --game-path "\(gameExe)"
        """
        try text.write(toFile: batPath, atomically: true, encoding: .utf8)
    }

    private func backupFileIfPresent(_ path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else { return }
        let stamp = DateFormatter.backupStamp.string(from: Date())
        let backup = "\(path).\(stamp).bak"
        if !FileManager.default.fileExists(atPath: backup) {
            try FileManager.default.copyItem(atPath: path, toPath: backup)
        }
    }

    private func resolvedProfilePath(_ path: String, in gameFolder: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "." else { return gameFolder }
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            return NSString(string: trimmed).expandingTildeInPath
        }
        return URL(fileURLWithPath: gameFolder).appendingPathComponent(trimmed).standardized.path
    }

    private func winePath(forMacPath path: String) -> String {
        let standardized = URL(fileURLWithPath: path).standardized.path
        let withoutLeadingSlash = standardized.hasPrefix("/") ? String(standardized.dropFirst()) : standardized
        return "Z:\\\(withoutLeadingSlash.replacingOccurrences(of: "/", with: "\\"))"
    }

    private static func defaultToolkitSourceFolder(home: String) -> String {
        "\(home)/Library/Application Support/RipperMoonKit/source"
    }

    func closeTargets(for profile: GameProfile) -> [String] {
        var targets: [String] = []
        let executable = (profile.executable as NSString).lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !executable.isEmpty {
            targets.append(executable)
        }
        if profile.isEldenRingERSC {
            targets.append("eldenring.exe")
        }
        if profile.useModEngine == true {
            targets.append(profile.modEngineLauncherName)
            targets.append("eldenring.exe")
        }
        var seen = Set<String>()
        return targets.filter { seen.insert($0.localizedLowercase).inserted }
    }

    private var sourceConfig: String {
        "[[ -r \(config.configPath.shellQuoted) ]] && source \(config.configPath.shellQuoted); ulimit -n \"${GPTK_NOFILE_LIMIT:-49152}\" 2>/dev/null || true"
    }

    /// Toolkit source shipped inside the packaged .app, if present.
    /// Lets first-run setup work offline with no GitHub clone.
    private var bundledToolkitFolder: String? {
        let candidate = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/toolkit", isDirectory: true)
        let installer = candidate.appendingPathComponent("install.zsh").path
        return FileManager.default.isExecutableFile(atPath: installer) ? candidate.path : nil
    }

    private var toolkitSourceBootstrapCommand: String {
        let source = toolkitSourceFolder.shellQuoted
        let repo = rmkRepositoryURL.shellQuoted
        let bundled = (bundledToolkitFolder ?? "").shellQuoted
        return """
        set -e
        echo "➡️ Preparing RipperMoonKit source…"
        repo=\(repo)
        src=\(source)
        bundled=\(bundled)
        mkdir -p "$(dirname "$src")"
        if [[ -x "$src/install.zsh" ]]; then
          echo "✅ Toolkit source ready: $src"
          cd "$src"
        elif [[ -n "$bundled" && -x "$bundled/install.zsh" ]]; then
          echo "📦 Installing bundled toolkit source into: $src"
          rm -rf "$src.tmp"
          ditto "$bundled" "$src.tmp"
          rm -rf "$src"
          mv "$src.tmp" "$src"
          cd "$src"
        else
          echo "⬇️ Cloning toolkit source into: $src"
          rm -rf "$src.tmp" "$src.tmp.zip"
          if git --version >/dev/null 2>&1; then
            git clone --depth 1 "$repo" "$src.tmp"
          else
            curl -fL "https://github.com/MoonTheRipper/RipperMoonKit/archive/refs/heads/main.zip" -o "$src.tmp.zip"
            unzip -q "$src.tmp.zip" -d "$(dirname "$src")"
            mv "$(dirname "$src")/RipperMoonKit-main" "$src.tmp"
            rm -f "$src.tmp.zip"
          fi
          rm -rf "$src"
          mv "$src.tmp" "$src"
          cd "$src"
        fi
        chmod +x ./install.zsh scripts/*.zsh 2>/dev/null || true
        """
    }

    private var setupSentinelURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/RipperMoonKit/.setup-complete")
    }

    private var setupIncompleteSentinelURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/RipperMoonKit/.setup-incomplete")
    }

    /// Runs a setup script in a real Terminal window so macOS can show the
    /// admin-password prompt (Homebrew) and the long GPTK download wait.
    /// The script ends with a loud banner and writes a result sentinel so the
    /// app can refresh without treating an incomplete GPTK install as success.
    private func runScriptInTerminal(named name: String, title: String, work: String) {
        let dir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/RipperMoonKit", isDirectory: true)
        let scriptURL = dir.appendingPathComponent("\(name).command")
        let sentinel = setupSentinelURL
        let incompleteSentinel = setupIncompleteSentinelURL
        try? FileManager.default.removeItem(at: sentinel)
        try? FileManager.default.removeItem(at: incompleteSentinel)

        let body = """
        #!/bin/zsh
        printf '\\033]0;RipperMoonKit Setup — running…\\007'
        clear
        (
        \(work)
        )
        work_status=$?
        mkdir -p \(dir.path.shellQuoted)

        verify_status=1
        if [[ "$work_status" -eq 0 ]]; then
          config_file="$HOME/.rippermoon-gptk.env"
          [[ -r "$config_file" ]] && source "$config_file"
          gptk_home="${GPTK_HOME:-$HOME/GPTK}"
          gptk_app_path="${GPTK_APP_PATH:-$gptk_home/apps/Game Porting Toolkit.app}"
          gptk_runtime="${GPTK_RUNTIME:-$gptk_home/runtime}"
          if [[ -r "$config_file" && -x "$HOME/bin/gptk-launch" && -x "$HOME/bin/gptk-steam" && -x "$gptk_app_path/Contents/Resources/wine/bin/wine64" && -f "$gptk_runtime/lib/wine/x86_64-windows/d3d12.dll" ]]; then
            verify_status=0
          fi
        fi

        if [[ "$work_status" -eq 0 && "$verify_status" -eq 0 ]]; then
          result_sentinel=\(sentinel.path.shellQuoted)
        else
          result_sentinel=\(incompleteSentinel.path.shellQuoted)
        fi
        date "+%Y-%m-%d %H:%M:%S" > "$result_sentinel"
        printf '\\a'
        echo
        if [[ "$work_status" -eq 0 && "$verify_status" -eq 0 ]]; then
          printf '\\033]0;RipperMoonKit Setup — FINISHED\\007'
          echo "════════════════════════════════════════════════"
          echo "   ✅  SETUP FINISHED"
          echo "════════════════════════════════════════════════"
          echo
          echo "RipperMoonKit refreshed itself — switch back to it to see"
          echo "what installed. You can now close this Terminal window."
        else
          printf '\\033]0;RipperMoonKit Setup — STOPPED\\007'
          echo "════════════════════════════════════════════════"
          echo "   ⚠️  SETUP INCOMPLETE"
          echo "════════════════════════════════════════════════"
          echo
          echo "RipperMoonKit did not verify all required pieces."
          echo "If GPTK is missing, download Game Porting Toolkit 3.0 from Apple,"
          echo "open the downloaded DMG so it mounts, then run setup again."
          echo "Switch back to RipperMoonKit to see which items still need setup."
        fi
        echo
        """

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try body.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        } catch {
            lastResult = "\(title) failed"
            commandOutput = "Could not prepare the setup script:\n\(error.localizedDescription)\n"
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", scriptURL.path]
        do {
            try process.run()
        } catch {
            lastResult = "\(title) failed"
            commandOutput = "Could not open Terminal:\n\(error.localizedDescription)\n"
            return
        }

        guidedSetupRunning = true
        lastResult = "\(title) running in Terminal"
        commandOutput = """
        \(title) is running in a Terminal window.

        Follow the steps shown there — macOS may ask for your Mac password once.
        Some steps copy several GB and look idle while they work; that is normal.

        RipperMoonKit refreshes itself the moment setup finishes — no need to watch.
        """
        watchForSetupCompletion()
    }

    /// Polls for the setup sentinel and refreshes the app when Terminal setup ends.
    private func watchForSetupCompletion() {
        let sentinel = setupSentinelURL
        let incompleteSentinel = setupIncompleteSentinelURL
        Task { @MainActor [weak self] in
            for _ in 0..<1200 { // up to ~60 minutes
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let self, self.guidedSetupRunning else { return }
                let complete = FileManager.default.fileExists(atPath: sentinel.path)
                let incomplete = FileManager.default.fileExists(atPath: incompleteSentinel.path)
                if complete || incomplete {
                    try? FileManager.default.removeItem(at: sentinel)
                    try? FileManager.default.removeItem(at: incompleteSentinel)
                    NSApp.activate(ignoringOtherApps: true)
                    self.reload()
                    if incomplete {
                        if !self.config.hasLocalGPTK {
                            self.awaitingGPTKDownload = true
                        }
                        self.lastResult = "Setup incomplete"
                        self.commandOutput = "Setup stopped before every required item was verified. Download and mount Game Porting Toolkit 3.0 if it is still missing, then click Begin GPTK Install.\n"
                    }
                    return
                }
            }
        }
    }

    private func runnerEnvAssignment(for profile: GameProfile) -> String {
        profile.runnerPath.isEmpty ? "" : "GPTK_WINE_HOME=\(profile.runnerPath.shellQuoted)"
    }

    private func toolPrefixName(for profile: GameProfile) -> String {
        let suffix = config.toolWineHome.localizedCaseInsensitiveContains("Wine Staging.app") ? "ToolsStaging" : "Tools"
        return profile.isEldenRingERSC ? "EldenRing\(suffix)" : "\(profile.safeName)-\(suffix)"
    }

    private func toolRunnerEnvAssignment() -> String {
        let wineHome = config.toolWineHome
        return wineHome.isEmpty ? "" : "GPTK_WINE_HOME=\(wineHome.shellQuoted)"
    }

    private func steamEnvAssignment(for profile: GameProfile) -> String {
        var assignments: [String] = []
        if !profile.runnerPath.isEmpty {
            assignments.append("GPTK_WINE_HOME=\(profile.runnerPath.shellQuoted)")
        }
        assignments.append("GPTK_MTL_HUD_ENABLED=\(profile.hud ? "1" : "0")")
        assignments.append("GPTK_WINEESYNC=\(profile.noEsync ? "0" : "1")")
        return assignments.joined(separator: " ")
    }

    private func dllOverrides(for profile: GameProfile) -> String {
        var values: [String] = []
        if profile.nativeWinmm { values.append("winmm=n,b") }
        if profile.nativeSteamAPI { values.append("steam_api64=n,b") }
        if profile.metalFX == true {
            values.append("nvapi64=b,n")
            values.append("nvngx=b,n")
        }
        if let extra = profile.extraDllOverrides, !extra.trimmingCharacters(in: .whitespaces).isEmpty {
            values.append(extra.trimmingCharacters(in: .whitespaces))
        }
        return values.joined(separator: ";")
    }

    private func envPath(_ path: String) -> String {
        if path == config.home {
            return "$HOME"
        }
        if path.hasPrefix(config.home + "/") {
            return "$HOME/" + path.dropFirst(config.home.count + 1)
        }
        return path
    }

    private func saveEnvValues(_ values: [String: String]) {
        do {
            try backupConfigForEdit()
            var lines: [String]
            if FileManager.default.fileExists(atPath: config.configPath) {
                let text = try String(contentsOfFile: config.configPath, encoding: .utf8)
                lines = text.components(separatedBy: .newlines)
            } else {
                lines = ["# RipperMoonToolKit configuration"]
            }

            var remaining = Set(values.keys)
            for index in lines.indices {
                let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
                let body = trimmed.hasPrefix("export ") ? String(trimmed.dropFirst("export ".count)) : trimmed
                guard let equal = body.firstIndex(of: "=") else { continue }
                let key = String(body[..<equal]).trimmingCharacters(in: .whitespaces)
                if let value = values[key] {
                    lines[index] = "export \(key)=\"\(value.envEscaped)\""
                    remaining.remove(key)
                }
            }

            for key in remaining.sorted() {
                lines.append("export \(key)=\"\(values[key, default: ""].envEscaped)\"")
            }

            try lines.joined(separator: "\n").write(toFile: config.configPath, atomically: true, encoding: .utf8)
            config = ToolkitConfig.load()
            pathSettings = PathSettings(config: config)
            lastResult = "Saved config"
        } catch {
            lastResult = "Config save failed"
            commandOutput += "\(error.localizedDescription)\n"
        }
    }

    private func backupConfigForEdit() throws {
        guard FileManager.default.fileExists(atPath: config.configPath) else { return }
        let stamp = DateFormatter.backupStamp.string(from: Date())
        let backup = "\(config.gptkHome)/backups/env-edit-\(stamp)/.rippermoon-gptk.env"
        try FileManager.default.createDirectory(atPath: (backup as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: config.configPath, toPath: backup)
    }

    private func runShell(
        title: String,
        command: String,
        detached: Bool = false,
        completion: (() -> Void)? = nil,
        successCompletion: (() -> Void)? = nil
    ) {
        defaults.set(toolkitSourceFolder, forKey: "toolkitSourceFolder")
        isRunning = true
        lastResult = "\(title) running"
        commandOutput = "$ \(command)\n"

        Task {
            let result = await ShellExecutor.run(command)
            isRunning = false
            commandOutput += result.output
            if let error = result.error {
                commandOutput += "\(error)\n"
                lastResult = "\(title) failed"
            } else {
                lastResult = detached ? "\(title) sent" : "\(title) finished with status \(result.status)"
            }
            completion?()
            if result.error == nil && result.status == 0 {
                successCompletion?()
            }
        }
    }

    private func relaunchAfterUpdate() {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else {
            commandOutput += "\nUpdate installed. Relaunch is only automatic from the packaged .app.\n"
            return
        }

        lastResult = "Update installed. Restarting app"
        commandOutput += "\nUpdate installed. RipperMoonKit will close and reopen.\n"
        let command = "sleep 1; open \(bundleURL.path.shellQuoted)"

        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]
            try? process.run()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NSApp.terminate(nil)
        }
    }

    private static func isVersion(_ candidate: String, newerThan installed: String) -> Bool {
        let lhs = versionParts(candidate)
        let rhs = versionParts(installed)
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right {
                return left > right
            }
        }
        return false
    }

    private static func versionParts(_ version: String) -> [Int] {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.drop { $0 == "v" || $0 == "V" }
        return withoutPrefix
            .split { $0 == "." || $0 == "-" || $0 == "_" }
            .map { token in
                let digits = token.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
    }

    private static func loadProfiles(config: ToolkitConfig, defaults: UserDefaults) -> [GameProfile] {
        if let data = defaults.data(forKey: "gameProfiles.v1"),
           let profiles = try? JSONDecoder().decode([GameProfile].self, from: data),
           !profiles.isEmpty {
            return repairProfiles(profiles, config: config)
        }
        return repairProfiles([GameProfile.steam(config: config), GameProfile.eldenRing(config: config, defaults: defaults)], config: config)
    }

    private static func repairProfiles(_ profiles: [GameProfile], config: ToolkitConfig) -> [GameProfile] {
        var repaired = profiles.map { $0.repairedForCurrentToolkit(config: config) }

        if !repaired.contains(where: { $0.isSteamApp }) {
            repaired.insert(GameProfile.steam(config: config), at: 0)
        }

        if let steamIndex = repaired.firstIndex(where: { $0.isSteamApp }), steamIndex != 0 {
            let steam = repaired.remove(at: steamIndex)
            repaired.insert(steam, at: 0)
        }

        for steamGame in discoverSteamGames(config: config) {
            if let existingIndex = repaired.firstIndex(where: { $0.steamAppID == steamGame.steamAppID }) {
                repaired[existingIndex].name = repaired[existingIndex].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? steamGame.name : repaired[existingIndex].name
                repaired[existingIndex].gameFolder = steamGame.gameFolder
                repaired[existingIndex].prefix = repaired[existingIndex].prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Steam" : repaired[existingIndex].prefix
                repaired[existingIndex].requiresSteam = true
                repaired[existingIndex].systemImage = repaired[existingIndex].systemImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? steamGame.systemImage : repaired[existingIndex].systemImage
            } else {
                repaired.append(steamGame)
            }
        }

        return repaired
    }

    private func repairedProfile(_ profile: GameProfile) -> GameProfile {
        let repaired = profile.repairedForCurrentToolkit(config: config)
        guard repaired != profile else { return profile }

        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = repaired
            persistProfiles()
        }
        return repaired
    }

    private static func discoverSteamGames(config: ToolkitConfig) -> [GameProfile] {
        let steamAppsURL = URL(fileURLWithPath: config.steamLibrary).appendingPathComponent("steamapps")
        let manifestURLs = ((try? FileManager.default.contentsOfDirectory(
            at: steamAppsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? [])
            .filter { url in
                let name = url.lastPathComponent
                return name.hasPrefix("appmanifest_") && name.hasSuffix(".acf")
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return manifestURLs.compactMap { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  let appID = acfValue("appid", in: text),
                  let name = acfValue("name", in: text),
                  let installDir = acfValue("installdir", in: text),
                  !appID.isEmpty,
                  !name.isEmpty,
                  !installDir.isEmpty else {
                return nil
            }

            return GameProfile.steamGame(appID: appID, name: name, installDir: installDir, config: config)
        }
    }

    private static func acfValue(_ key: String, in text: String) -> String? {
        let pattern = #""\#(key)"\s+"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[valueRange])
    }
}

private enum ShellExecutor {
    static func run(_ command: String) async -> ShellResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", command]
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    // Drain the pipe *before* waiting — large output (e.g. `ps -axww`)
                    // overruns the ~64 KB pipe buffer and would otherwise deadlock:
                    // the child blocks on write while waitUntilExit() blocks on the child.
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: ShellResult(status: process.terminationStatus, output: output, error: nil))
                } catch {
                    continuation.resume(returning: ShellResult(status: -1, output: "", error: error.localizedDescription))
                }
            }
        }
    }
}

private struct ShellResult: Sendable {
    let status: Int32
    let output: String
    let error: String?
}

private struct GameProfile: Codable, Identifiable, Hashable {
    private static let eldenRingERSCID = UUID(uuidString: "00000000-0000-0000-0000-000000000480") ?? UUID()
    private static let steamClientID = UUID(uuidString: "00000000-0000-0000-0000-000000000481") ?? UUID()

    var id: UUID
    var name: String
    var prefix: String
    var gameFolder: String
    var executable: String
    var steamAppID: String?
    var iconPath: String?
    var runnerPath: String
    var winver: String
    var requiresSteam: Bool
    var noDXR: Bool
    var avx: Bool?
    var metalFX: Bool?
    var hud: Bool
    var noEsync: Bool
    var nativeWinmm: Bool
    var nativeSteamAPI: Bool
    var extraDllOverrides: String?
    var extraArguments: String
    var requiredFiles: [String]
    var systemImage: String
    var useModEngine: Bool?
    var modEngineFolder: String?
    var modEngineLauncher: String?
    var modEngineConfig: String?
    var modEngineLaunchBat: String?
    var randomizerExecutable: String?
    var seamlessDllPath: String?

    var safeName: String {
        name.replacingOccurrences(of: "[^A-Za-z0-9._-]+", with: "-", options: .regularExpression)
    }

    var isEldenRingERSC: Bool {
        id == Self.eldenRingERSCID ||
            executable.localizedCaseInsensitiveContains("ersc_launcher.exe") ||
            name.localizedCaseInsensitiveContains("elden ring ersc")
    }

    var supportsModEngine: Bool {
        isEldenRingERSC || name.localizedCaseInsensitiveContains("elden ring")
    }

    var modEngineFolderPath: String {
        cleanOptional(modEngineFolder, fallback: "ModEngine2")
    }

    var modEngineLauncherName: String {
        cleanOptional(modEngineLauncher, fallback: "modengine2_launcher.exe")
    }

    var modEngineConfigName: String {
        cleanOptional(modEngineConfig, fallback: "config_eldenring.toml")
    }

    var modEngineLaunchBatName: String {
        cleanOptional(modEngineLaunchBat, fallback: "launchmod_eldenring.bat")
    }

    var randomizerExecutablePath: String {
        cleanOptional(randomizerExecutable, fallback: "randomizer/EldenRingRandomizer.exe")
    }

    var seamlessDllConfigPath: String {
        cleanOptional(seamlessDllPath, fallback: "../SeamlessCoop/ersc.dll")
    }

    var isSteamApp: Bool {
        id == Self.steamClientID || (name == "Steam" && prefix == "Steam" && steamAppID == nil)
    }

    var isSteamLibraryGame: Bool {
        !(steamAppID ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSteamApp
    }

    var isSteamManaged: Bool {
        isSteamApp || isSteamLibraryGame
    }

    var isRequiredLibraryProfile: Bool {
        isSteamApp
    }

    func repairedForCurrentToolkit(config: ToolkitConfig) -> GameProfile {
        if isSteamApp {
            var repaired = self
            repaired.id = Self.steamClientID
            repaired.name = "Steam"
            repaired.prefix = "Steam"
            repaired.gameFolder = "\(config.prefixRoot)/Steam"
            repaired.executable = "steam.exe"
            repaired.steamAppID = nil
            repaired.requiresSteam = false
            repaired.requiredFiles = []
            repaired.systemImage = "square.grid.2x2.fill"
            return repaired
        }

        guard isEldenRingERSC else { return self }

        var repaired = self
        let patchedRunner = "\(config.gptkHome)/runners/gptk-dsound-nocap-20260513"
        let patchedRunnerExists = FileManager.default.isExecutableFile(atPath: "\(patchedRunner)/bin/wine64")
        let stockRunnerPaths = [
            config.gptkWineHome,
            "\(config.gptkHome)/apps/Game Porting Toolkit.app/Contents/Resources/wine",
            "/Applications/Game Porting Toolkit.app/Contents/Resources/wine"
        ]

        repaired.prefix = repaired.prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Steam" : repaired.prefix
        repaired.executable = "ersc_launcher.exe"
        repaired.winver = repaired.winver.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "win10" : repaired.winver
        repaired.requiresSteam = true
        repaired.noDXR = true
        repaired.noEsync = true
        repaired.nativeWinmm = true
        repaired.nativeSteamAPI = true
        repaired.systemImage = "gamecontroller.fill"
        repaired.modEngineFolder = repaired.modEngineFolder ?? "ModEngine2"
        repaired.modEngineLauncher = repaired.modEngineLauncher ?? "modengine2_launcher.exe"
        repaired.modEngineConfig = repaired.modEngineConfig ?? "config_eldenring.toml"
        repaired.modEngineLaunchBat = repaired.modEngineLaunchBat ?? "launchmod_eldenring.bat"
        repaired.randomizerExecutable = repaired.randomizerExecutable ?? "randomizer/EldenRingRandomizer.exe"
        repaired.seamlessDllPath = repaired.seamlessDllPath ?? "../SeamlessCoop/ersc.dll"

        for required in ["eldenring.exe", "SeamlessCoop"] where !repaired.requiredFiles.contains(required) {
            repaired.requiredFiles.append(required)
        }

        let runner = repaired.runnerPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let runnerMissing = runner.isEmpty || !FileManager.default.isExecutableFile(atPath: "\(runner)/bin/wine64")
        let runnerIsStock = stockRunnerPaths.contains(runner)
        if patchedRunnerExists, runnerMissing || runnerIsStock {
            repaired.runnerPath = patchedRunner
        }

        return repaired
    }

    static func eldenRing(config: ToolkitConfig, defaults: UserDefaults) -> GameProfile {
        GameProfile(
            id: eldenRingERSCID,
            name: "Elden Ring ERSC",
            prefix: defaults.string(forKey: "prefix") ?? "Steam",
            gameFolder: defaults.string(forKey: "gameFolder") ?? "\(config.externalRoot)/Games/EldenRing/Game",
            executable: "ersc_launcher.exe",
            steamAppID: nil,
            iconPath: defaults.string(forKey: "iconPath"),
            runnerPath: defaults.string(forKey: "runnerPath") ?? "\(config.gptkHome)/runners/gptk-dsound-nocap-20260513",
            winver: defaults.string(forKey: "winver") ?? "win10",
            requiresSteam: true,
            noDXR: defaults.object(forKey: "noDXR") as? Bool ?? true,
            avx: nil,
            metalFX: false,
            hud: defaults.object(forKey: "hud") as? Bool ?? false,
            noEsync: defaults.object(forKey: "noEsync") as? Bool ?? true,
            nativeWinmm: defaults.object(forKey: "nativeWinmm") as? Bool ?? true,
            nativeSteamAPI: defaults.object(forKey: "nativeSteamAPI") as? Bool ?? true,
            extraDllOverrides: nil,
            extraArguments: "",
            requiredFiles: ["eldenring.exe", "SeamlessCoop"],
            systemImage: "gamecontroller.fill",
            useModEngine: false,
            modEngineFolder: "ModEngine2",
            modEngineLauncher: "modengine2_launcher.exe",
            modEngineConfig: "config_eldenring.toml",
            modEngineLaunchBat: "launchmod_eldenring.bat",
            randomizerExecutable: "randomizer/EldenRingRandomizer.exe",
            seamlessDllPath: "../SeamlessCoop/ersc.dll"
        )
    }

    static func empty(config: ToolkitConfig) -> GameProfile {
        GameProfile(
            id: UUID(),
            name: "New App",
            prefix: "MyGame",
            gameFolder: "\(config.externalRoot)/Games",
            executable: "Game.exe",
            steamAppID: nil,
            iconPath: nil,
            runnerPath: "",
            winver: "win10",
            requiresSteam: false,
            noDXR: false,
            avx: nil,
            metalFX: false,
            hud: false,
            noEsync: false,
            nativeWinmm: false,
            nativeSteamAPI: false,
            extraDllOverrides: nil,
            extraArguments: "",
            requiredFiles: [],
            systemImage: "app.fill",
            useModEngine: false,
            modEngineFolder: nil,
            modEngineLauncher: nil,
            modEngineConfig: nil,
            modEngineLaunchBat: nil,
            randomizerExecutable: nil,
            seamlessDllPath: nil
        )
    }

    static func steam(config: ToolkitConfig) -> GameProfile {
        GameProfile(
            id: steamClientID,
            name: "Steam",
            prefix: "Steam",
            gameFolder: "\(config.prefixRoot)/Steam",
            executable: "steam.exe",
            steamAppID: nil,
            iconPath: nil,
            runnerPath: "",
            winver: "win10",
            requiresSteam: false,
            noDXR: false,
            avx: nil,
            metalFX: false,
            hud: false,
            noEsync: false,
            nativeWinmm: false,
            nativeSteamAPI: false,
            extraDllOverrides: nil,
            extraArguments: "",
            requiredFiles: [],
            systemImage: "square.grid.2x2.fill",
            useModEngine: false,
            modEngineFolder: nil,
            modEngineLauncher: nil,
            modEngineConfig: nil,
            modEngineLaunchBat: nil,
            randomizerExecutable: nil,
            seamlessDllPath: nil
        )
    }

    static func steamGame(appID: String, name: String, installDir: String, config: ToolkitConfig) -> GameProfile {
        GameProfile(
            id: UUID(),
            name: name,
            prefix: "Steam",
            gameFolder: "\(config.steamLibrary)/steamapps/common/\(installDir)",
            executable: "",
            steamAppID: appID,
            iconPath: nil,
            runnerPath: "",
            winver: "win10",
            requiresSteam: true,
            noDXR: false,
            avx: nil,
            metalFX: false,
            hud: false,
            noEsync: false,
            nativeWinmm: false,
            nativeSteamAPI: false,
            extraDllOverrides: nil,
            extraArguments: "",
            requiredFiles: [],
            systemImage: "gamecontroller.fill",
            useModEngine: false,
            modEngineFolder: nil,
            modEngineLauncher: nil,
            modEngineConfig: nil,
            modEngineLaunchBat: nil,
            randomizerExecutable: nil,
            seamlessDllPath: nil
        )
    }

    private func cleanOptional(_ value: String?, fallback: String) -> String {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

private struct PathSettings: Hashable {
    var gptkHome: String
    var prefixRoot: String
    var gamesRoot: String
    var externalRoot: String
    var steamLibrary: String

    init(config: ToolkitConfig) {
        gptkHome = config.gptkHome
        prefixRoot = config.prefixRoot
        gamesRoot = config.gamesRoot
        externalRoot = config.externalRoot
        steamLibrary = config.steamLibrary
    }
}

private struct DriveMap: Codable, Identifiable, Hashable {
    var id = UUID()
    var letter: String
    var path: String

    init(letter: String, path: String) {
        self.letter = letter
        self.path = path
    }

    init?(line: String) {
        let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        letter = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        path = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parse(_ value: String) -> [DriveMap] {
        value.strippedShellQuotes
            .split(separator: ";")
            .compactMap { DriveMap(line: String($0)) }
    }
}

private struct BackupItem: Identifiable, Hashable {
    let name: String
    let path: String
    let modified: Date

    var id: String { path }
}

private struct ValidationItem: Hashable {
    let title: String
    let isOK: Bool
}

private struct ToolkitConfig {
    let home: String
    let configPath: String
    let values: [String: String]
    let exists: Bool

    var gptkHome: String { expand(values["GPTK_HOME"] ?? "$HOME/GPTK") }
    var prefixRoot: String { expand(values["GPTK_PREFIX_ROOT"] ?? "$HOME/WinePrefixes") }
    var gamesRoot: String { expand(values["GPTK_GAMES_ROOT"] ?? "$HOME/Games") }
    var externalRoot: String { expand(values["GPTK_EXTERNAL_ROOT"] ?? "$HOME/Library/Application Support/RipperMoonKit") }
    var steamLibrary: String { expand(values["GPTK_STEAM_LIBRARY"] ?? "$GPTK_EXTERNAL_ROOT/SteamLibrary") }
    var logsPath: String { expand(values["GPTK_LOG_DIR"] ?? "$GPTK_HOME/logs") }
    var gptkAppPath: String { expand(values["GPTK_APP_PATH"] ?? "$GPTK_HOME/apps/Game Porting Toolkit.app") }
    var localGPTKWineHome: String { "\(gptkAppPath)/Contents/Resources/wine" }
    var gptkWineHome: String { expand(values["GPTK_WINE_HOME"] ?? "$GPTK_HOME/apps/Game Porting Toolkit.app/Contents/Resources/wine") }
    var effectiveWineHome: String { detectedWineHome ?? gptkWineHome }
    var toolWineHome: String {
        toolWineHomeCandidates.first(where: hasWineExecutable) ?? effectiveWineHome
    }
    var gptkRuntime: String { expand(values["GPTK_RUNTIME"] ?? "$GPTK_HOME/runtime") }
    var gptkDownloadDir: String { expand(values["GPTK_DOWNLOAD_DIR"] ?? "$HOME/Downloads") }
    var gptkDownloadPage: String { expand(values["GPTK_DOWNLOAD_PAGE"] ?? "https://developer.apple.com/games/game-porting-toolkit/") }
    var steamSetupPath: String {
        expand(values["STEAM_SETUP_PATH"] ?? "$HOME/Library/Application Support/RipperMoonKit/Downloads/SteamSetup.exe")
    }
    var gptkLaunchPath: String { "\(home)/bin/gptk-launch" }
    var gptkSteamPath: String { "\(home)/bin/gptk-steam" }
    var gptkVCRunPath: String { "\(home)/bin/gptk-vcrun" }
    var gptkDotNet6Path: String { "\(home)/bin/gptk-dotnet6" }
    var gptkStubsPath: String { "\(home)/bin/gptk-stubs" }
    var hasToolkitScripts: Bool {
        FileManager.default.isExecutableFile(atPath: gptkLaunchPath)
            && FileManager.default.isExecutableFile(atPath: gptkSteamPath)
    }
    var hasWineRunner: Bool { detectedWineHome != nil }
    var hasLocalWineRunner: Bool {
        FileManager.default.isExecutableFile(atPath: "\(localGPTKWineHome)/bin/wine64")
    }
    var hasD3DMetalRuntime: Bool {
        d3d12Candidates.contains { FileManager.default.fileExists(atPath: $0) }
    }
    var hasLocalD3DMetalRuntime: Bool {
        FileManager.default.fileExists(atPath: "\(gptkRuntime)/lib/wine/x86_64-windows/d3d12.dll")
    }
    var hasLocalGPTK: Bool {
        hasLocalWineRunner && hasLocalD3DMetalRuntime
    }
    var hasGPTKInstallMedia: Bool {
        downloadedGPTKDmgPath != nil
            || mountedGPTKRuntimeSource != nil
            || hasLocalD3DMetalRuntime
    }
    var gptkInstallMediaStatus: String {
        if hasLocalGPTK {
            return "GPTK is already installed locally."
        }
        if let runtime = mountedGPTKRuntimeSource {
            if let app = mountedGPTKAppSource {
                return "GPTK runtime and app source detected: \(runtime) + \(app)"
            }
            return "GPTK runtime detected. The app runner will be installed with Homebrew if needed."
        }
        if hasLocalD3DMetalRuntime {
            if let app = mountedGPTKAppSource {
                return "Local GPTK runtime exists. GPTK app source detected: \(app)"
            }
            return "Local GPTK runtime exists. The app runner will be installed with Homebrew if needed."
        }
        if let app = mountedGPTKAppSource {
            return "GPTK app source detected: \(app). The GPTK 3.0 runtime is still needed."
        }
        if let dmg = downloadedGPTKDmgPath {
            return "GPTK download detected: \(dmg)"
        }
        return "Waiting for GPTK 3.0 in Downloads, Desktop, or mounted Finder volumes."
    }
    var needsSetupGuide: Bool {
        !exists || !hasToolkitScripts || !hasLocalGPTK
    }

    private var detectedWineHome: String? {
        wineHomeCandidates.first(where: hasWine64Executable)
    }

    private var d3d12Candidates: [String] {
        uniqued(["\(gptkRuntime)/lib/wine/x86_64-windows/d3d12.dll"] + wineHomeCandidates.map {
            "\($0)/lib/wine/x86_64-windows/d3d12.dll"
        })
    }

    private var mountedGPTKAppSource: String? {
        firstDescendant(in: gptkAppSourceRoots, maxDepth: 5) { url in
            url.lastPathComponent == "Game Porting Toolkit.app"
                && FileManager.default.isExecutableFile(atPath: url.appendingPathComponent("Contents/Resources/wine/bin/wine64").path)
        }
    }

    private var mountedGPTKRuntimeSource: String? {
        firstDescendant(in: gptkMediaRoots, maxDepth: 5) { url in
            isGPTKRuntimeRoot(url)
        }
    }

    private var downloadedGPTKDmgPath: String? {
        firstDescendant(in: [gptkDownloadDir, "\(home)/Desktop"], maxDepth: 4) { url in
            let name = url.lastPathComponent.lowercased()
            guard name.hasSuffix(".dmg") else { return false }
            return name.contains("game porting toolkit")
                || (name.contains("game") && name.contains("porting") && name.contains("toolkit"))
                || name.contains("evaluation environment for windows games")
        }
    }

    private var gptkMediaRoots: [String] {
        var roots: [String] = []
        if let source = values["GPTK_SOURCE"]?.strippedShellQuotes, !source.isEmpty {
            roots.append(expand(source))
        }
        if let volumeURLs = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes", isDirectory: true),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            roots.append(contentsOf: volumeURLs.map(\.path))
        }
        return uniqued(roots)
    }

    private var gptkAppSourceRoots: [String] {
        uniqued(gptkMediaRoots + [
            "/Applications",
            "\(home)/Applications"
        ])
    }

    private var wineHomeCandidates: [String] {
        var candidates = [
            gptkWineHome,
            "\(gptkHome)/apps/Game Porting Toolkit.app/Contents/Resources/wine",
            "/Applications/Game Porting Toolkit.app/Contents/Resources/wine",
            "/Applications/Wine Stable.app/Contents/Resources/wine",
            "/Applications/Wine Staging.app/Contents/Resources/wine"
        ]

        let runnersURL = URL(fileURLWithPath: "\(gptkHome)/runners")
        if let runnerURLs = try? FileManager.default.contentsOfDirectory(
            at: runnersURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            candidates.append(contentsOf: runnerURLs.compactMap { url in
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                    return nil
                }
                return url.path
            })
        }

        return uniqued(candidates)
    }

    private func isGPTKRuntimeRoot(_ url: URL) -> Bool {
        let directLib = url.appendingPathComponent("lib")
        let redistLib = url.appendingPathComponent("redist/lib")
        return isGPTKRuntimeLibRoot(directLib) || isGPTKRuntimeLibRoot(redistLib)
    }

    private func isGPTKRuntimeLibRoot(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent("wine/x86_64-windows/d3d12.dll").path)
            && FileManager.default.fileExists(atPath: url.appendingPathComponent("external").path)
    }

    private func firstDescendant(
        in roots: [String],
        maxDepth: Int,
        matching predicate: (URL) -> Bool
    ) -> String? {
        let manager = FileManager.default
        for root in roots {
            let rootURL = URL(fileURLWithPath: root)
            guard manager.fileExists(atPath: rootURL.path) else { continue }
            if predicate(rootURL) {
                return rootURL.path
            }
            guard let enumerator = manager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator {
                let depth = url.pathComponents.count - rootURL.pathComponents.count
                if depth > maxDepth {
                    enumerator.skipDescendants()
                    continue
                }
                if predicate(url) {
                    return url.path
                }
            }
        }
        return nil
    }

    private var toolWineHomeCandidates: [String] {
        uniqued([
            "/Applications/Wine Staging.app/Contents/Resources/wine",
            "/Applications/Wine Stable.app/Contents/Resources/wine",
            effectiveWineHome
        ].map(expand))
    }

    private func hasWine64Executable(_ path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: "\(path)/bin/wine64")
    }

    private func hasWineExecutable(_ path: String) -> Bool {
        hasWine64Executable(path) || FileManager.default.isExecutableFile(atPath: "\(path)/bin/wine")
    }

    private func uniqued(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    static func load() -> ToolkitConfig {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let configPath = "\(home)/.rippermoon-gptk.env"
        let url = URL(fileURLWithPath: configPath)
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return ToolkitConfig(
            home: home,
            configPath: configPath,
            values: parse(text),
            exists: FileManager.default.fileExists(atPath: configPath)
        )
    }

    private func expand(_ raw: String) -> String {
        var result = raw.strippedShellQuotes
        for _ in 0..<6 {
            result = result
                .replacingOccurrences(of: "${HOME}", with: home)
                .replacingOccurrences(of: "$HOME", with: home)

            for (key, value) in values {
                let expandedValue = value.strippedShellQuotes
                    .replacingOccurrences(of: "${HOME}", with: home)
                    .replacingOccurrences(of: "$HOME", with: home)
                result = result
                    .replacingOccurrences(of: "${\(key)}", with: expandedValue)
                    .replacingOccurrences(of: "$\(key)", with: expandedValue)
            }
        }
        return result
    }

    private static func parse(_ text: String) -> [String: String] {
        var output: [String: String] = [:]
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = String(rawLine).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if line.hasPrefix("export ") {
                line.removeFirst("export ".count)
            }
            guard let equalIndex = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<equalIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: equalIndex)...]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty {
                output[key] = value.strippedShellQuotes
            }
        }
        return output
    }
}

private extension DateFormatter {
    static let backupStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

private extension String {
    var shellQuoted: String {
        "'\(replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    var envEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    var strippedShellQuotes: String {
        var value = trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count >= 2 {
            let first = value.first
            let last = value.last
            if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
                value.removeFirst()
                value.removeLast()
            }
        }
        return value
    }

    var safeShellIdentifier: String {
        let cleaned = replacingOccurrences(of: "[^A-Za-z0-9._-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-."))
        return cleaned.isEmpty ? "default" : cleaned
    }

    var tomlEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
