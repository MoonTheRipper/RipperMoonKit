import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings

struct SettingsScreen: View {
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
