import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Backups

struct BackupsScreen: View {
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
