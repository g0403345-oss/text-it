//
//  SyncDiagnosticsView.swift
//  Text it
//

import SwiftUI
import CloudKit
import SwiftData

struct SyncDiagnosticsView: View {
    @State private var diag = SyncDiagnostics.shared
    @State private var monitor = SyncMonitor.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \DeviceNode.lastSeen, order: .reverse) private var devices: [DeviceNode]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "icloud.fill")
                    .font(.title)
                    .foregroundStyle(.tint)
                Text("iCloud-Synchronisation")
                    .font(.title2.bold())
                Spacer()
                Button("Schließen") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                Section("Status") {
                    row("Aktuell",        value: monitor.state.label,      color: monitor.state.tint,    icon: monitor.state.systemImage)
                    row("iCloud-Konto",   value: diag.accountStatusLabel,  color: diag.accountStatusColor, icon: "person.icloud")
                    if let err = diag.accountError {
                        row("Fehler", value: err, color: .red, icon: "exclamationmark.triangle")
                    }
                }

                Section("Verbundene Geräte") {
                    if devices.isEmpty {
                        Text("Noch keine Geräte sichtbar. Sobald iPad und Mac mit derselben Apple-ID online sind, erscheinen sie hier.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(devices) { dev in
                        deviceRow(dev)
                    }
                }

                Section("Dieses Gerät") {
                    row("Name",        value: diag.deviceName,    color: .secondary, icon: "laptopcomputer.and.iphone")
                    row("Plattform",   value: DeviceHeartbeat.platform, color: .secondary, icon: DeviceHeartbeat.platformSymbol)
                    row("Container",   value: diag.containerID,   color: .secondary, icon: "tray.full")
                }

                Section("Aktivität") {
                    row("Letzter Import aus iCloud",
                        value: diag.lastRemoteChange.map(format) ?? "–",
                        color: diag.lastRemoteChange == nil ? .secondary : .green,
                        icon: "arrow.down.circle")
                    row("Letzte lokale Speicherung",
                        value: diag.lastLocalSave.map(format) ?? "–",
                        color: diag.lastLocalSave == nil ? .secondary : .blue,
                        icon: "arrow.up.circle")
                }

                Section("Aktionen") {
                    Button {
                        diag.refreshAccount()
                        DeviceHeartbeat.shared.beat()
                        SyncMonitor.shared.triggerSync()
                    } label: {
                        Label("Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath")
                    }
                    if diag.accountStatus == .noAccount {
                        Link(destination: settingsURL) {
                            Label("In iCloud anmelden", systemImage: "gear")
                        }
                    }
                }

                Section("Hinweise") {
                    Text("Damit dein iPad und dein Mac Notizen automatisch live miteinander teilen, müssen:")
                        .font(.callout)
                    bullet("Beide Geräte mit derselben Apple-ID angemeldet sein.")
                    bullet("iCloud Drive aktiv sein.")
                    bullet("Im Xcode-Target die Capabilities 'iCloud → CloudKit' und 'Background Modes → Remote notifications' gesetzt sein.")
                    bullet("Der CloudKit-Container '\(diag.containerID)' verfügbar sein.")
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 540, minHeight: 620)
    }

    private func deviceRow(_ dev: DeviceNode) -> some View {
        let isThis = dev.installID == DeviceHeartbeat.shared.installID
        let interval = Date().timeIntervalSince(dev.lastSeen)
        let online = interval < 90
        return HStack {
            Image(systemName: symbol(for: dev.platform))
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(online ? .green : .secondary)
            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text(dev.name.isEmpty ? "Unbekanntes Gerät" : dev.name)
                        .fontWeight(.medium)
                    if isThis {
                        Text("dieses Gerät")
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.tint.opacity(0.15), in: Capsule())
                    }
                }
                Text("\(dev.platform) · \(dev.systemVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Circle()
                    .fill(online ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(online ? "online" : format(dev.lastSeen))
                    .font(.caption2)
                    .foregroundStyle(online ? .green : .secondary)
            }
        }
    }

    private func symbol(for platform: String) -> String {
        switch platform {
        case "Mac":    return "macbook"
        case "iPad":   return "ipad"
        case "iPhone": return "iphone"
        case "Vision": return "vision.pro"
        default:       return "desktopcomputer"
        }
    }

    private var settingsURL: URL {
        #if canImport(UIKit)
        return URL(string: UIApplication.openSettingsURLString) ?? URL(string: "https://icloud.com")!
        #else
        return URL(string: "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane")!
        #endif
    }

    private func row(_ label: String, value: String, color: Color, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value)
                .foregroundStyle(color)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "circle.fill").font(.system(size: 4)).padding(.top, 7)
            Text(text)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    private func format(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }
}
