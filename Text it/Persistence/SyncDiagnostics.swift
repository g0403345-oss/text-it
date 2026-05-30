//
//  SyncDiagnostics.swift
//  Text it
//
//  Detaillierte Diagnose des iCloud-/CloudKit-Status:
//  - Account-Status
//  - Container-ID
//  - Gerätename
//  - Letzter Sync
//  - Live-Auslöser für Remote-Fetch
//

import SwiftUI
import CloudKit
import CoreData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
@Observable
final class SyncDiagnostics {
    static let shared = SyncDiagnostics()

    var accountStatus: CKAccountStatus = .couldNotDetermine
    var accountError: String?
    var containerID: String = "iCloud.de.justinguel.Text-it"
    var deviceName: String = SyncDiagnostics.currentDeviceName()
    var lastRemoteChange: Date?
    var lastLocalSave: Date?

    private var remoteObserver: NSObjectProtocol?
    private var saveObserver: NSObjectProtocol?

    init() {
        refreshAccount()
        observeRemoteChanges()
        observeLocalSaves()
        observeAccountChanges()
    }

    static func currentDeviceName() -> String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #elseif canImport(AppKit)
        return Host.current().localizedName ?? "Mac"
        #else
        return "Gerät"
        #endif
    }

    func refreshAccount() {
        let container = CKContainer(identifier: containerID)
        container.accountStatus { [weak self] status, error in
            Task { @MainActor in
                self?.accountStatus = status
                self?.accountError = error?.localizedDescription
            }
        }
    }

    var accountStatusLabel: String {
        switch accountStatus {
        case .available:           return "Angemeldet"
        case .noAccount:           return "Nicht bei iCloud angemeldet"
        case .restricted:          return "Eingeschränkt"
        case .couldNotDetermine:   return "Wird geprüft…"
        case .temporarilyUnavailable: return "Vorübergehend nicht verfügbar"
        @unknown default:          return "Unbekannt"
        }
    }

    var accountStatusColor: Color {
        switch accountStatus {
        case .available:           return .green
        case .noAccount, .restricted: return .red
        default:                   return .orange
        }
    }

    private func observeRemoteChanges() {
        // Wird vom Persistent Store gepostet, sobald CloudKit Änderungen
        // aus dem Cloud-Konto importiert hat.
        remoteObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.lastRemoteChange = Date()
                NotificationCenter.default.post(name: .textitRemoteImport, object: nil)
            }
        }
    }

    private func observeLocalSaves() {
        saveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.lastLocalSave = Date()
            }
        }
    }

    private func observeAccountChanges() {
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshAccount() }
        }
    }
}

extension Notification.Name {
    /// Wird gepostet, sobald aus iCloud importierte Änderungen lokal verfügbar sind.
    static let textitRemoteImport = Notification.Name("textit.remoteImport")
}
