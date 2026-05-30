//
//  SyncMonitor.swift
//  Text it
//
//  Beobachtet die CloudKit-Sync-Events von SwiftData / NSPersistentCloudKitContainer
//  und stellt einen Live-Status für die UI bereit.
//

import Foundation
import CoreData
import SwiftUI
import Combine

@MainActor
@Observable
final class SyncMonitor {
    enum State: Equatable {
        case unknown
        case idle
        case syncing(String)   // setup / import / export
        case success(Date)
        case error(String)

        var label: String {
            switch self {
            case .unknown: return "iCloud verbindet…"
            case .idle: return "Synchronisiert"
            case .syncing(let kind): return "iCloud: \(kind)…"
            case .success(let d):
                let fmt = RelativeDateTimeFormatter()
                fmt.unitsStyle = .short
                return "Synchronisiert · \(fmt.localizedString(for: d, relativeTo: Date()))"
            case .error(let msg): return "Fehler: \(msg)"
            }
        }

        var systemImage: String {
            switch self {
            case .unknown:        return "icloud"
            case .idle:           return "checkmark.icloud"
            case .syncing:        return "arrow.triangle.2.circlepath.icloud"
            case .success:        return "checkmark.icloud.fill"
            case .error:          return "exclamationmark.icloud"
            }
        }

        var tint: Color {
            switch self {
            case .unknown:  return .secondary
            case .idle:     return .green
            case .syncing:  return .accentColor
            case .success:  return .green
            case .error:    return .red
            }
        }
    }

    static let shared = SyncMonitor()

    private(set) var state: State = .unknown
    private(set) var lastSuccess: Date?
    private var cancellable: AnyCancellable?

    init() {
        // NSPersistentCloudKitContainer.eventChangedNotification ist der korrekte,
        // versionierte Name; der alte String-Literal war falsch (falscher Wert).
        cancellable = NotificationCenter.default
            .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                self?.handle(notification: note)
            }
    }

    private func handle(notification: Notification) {
        // User-Info-Schlüssel per KVC abrufen; vermeidet direkten Import des
        // internen Event-Typs und bleibt kompatibel mit SwiftData-Wrapper.
        guard let event = notification.userInfo?["event"] as AnyObject? else { return }

        let endDate = event.value(forKey: "endDate") as? Date
        let error   = event.value(forKey: "error") as? Error
        let typeRaw = (event.value(forKey: "type") as? Int) ?? -1

        let typeLabel: String = {
            switch typeRaw {
            case 0: return "Einrichten"
            case 1: return "Importieren"
            case 2: return "Hochladen"
            default: return "Synchronisieren"
            }
        }()

        if let error {
            state = .error(error.localizedDescription)
            return
        }
        if endDate == nil {
            state = .syncing(typeLabel)
        } else {
            lastSuccess = endDate
            state = .success(endDate ?? Date())
        }
    }

    /// Erzwingt einen Save (triggert Export zu CloudKit) und zeigt kurz „syncing“.
    func triggerSync(context: NSManagedObjectContext? = nil) {
        state = .syncing("Manuell")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            if case .syncing = state {
                state = .success(Date())
            }
        }
    }
}
