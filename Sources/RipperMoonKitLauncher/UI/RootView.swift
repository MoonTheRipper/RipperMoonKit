import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
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
