//
//  SyncStatusView.swift
//  Text it
//

import SwiftUI
import SwiftData

struct SyncStatusView: View {
    @Environment(\.modelContext) private var context
    @State private var monitor = SyncMonitor.shared
    @State private var diag = SyncDiagnostics.shared
    @State private var showDetails = false
    @Query(sort: \DeviceNode.lastSeen, order: .reverse) private var devices: [DeviceNode]

    private var onlineDevices: [DeviceNode] {
        devices.filter { Date().timeIntervalSince($0.lastSeen) < 90 }
    }

    var body: some View {
        Menu {
            Text(monitor.state.label)
            Text("Konto: \(diag.accountStatusLabel)")
            Divider()
            if onlineDevices.isEmpty {
                Text("Keine anderen Geräte online")
            } else {
                ForEach(onlineDevices) { dev in
                    Label("\(dev.name) (\(dev.platform))",
                          systemImage: symbol(for: dev.platform))
                }
            }
            Divider()
            Button {
                forceSyncNow()
            } label: {
                Label("Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath")
            }
            Button {
                showDetails = true
            } label: {
                Label("Sync-Diagnose öffnen…", systemImage: "info.circle")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: monitor.state.systemImage)
                    .foregroundStyle(monitor.state.tint)
                    .symbolEffect(.pulse, options: .repeating, isActive: isSyncing)
                Circle()
                    .fill(diag.accountStatusColor)
                    .frame(width: 6, height: 6)
                Text(shortLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !onlineDevices.isEmpty {
                    Text("· \(onlineDevices.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: "laptopcomputer.and.iphone")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.5), in: Capsule())
        }
        .menuStyle(.borderlessButton)
        .help("\(monitor.state.label) · \(diag.accountStatusLabel)")
        .sheet(isPresented: $showDetails) {
            SyncDiagnosticsView()
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

    private var isSyncing: Bool {
        if case .syncing = monitor.state { return true }
        return false
    }

    private var shortLabel: String {
        switch monitor.state {
        case .unknown:        return "iCloud…"
        case .idle:           return "Sync aktiv"
        case .syncing:        return "Sync läuft"
        case .success:        return "Synchron"
        case .error:          return "Sync-Fehler"
        }
    }

    private func forceSyncNow() {
        try? context.save()
        monitor.triggerSync()
    }
}
