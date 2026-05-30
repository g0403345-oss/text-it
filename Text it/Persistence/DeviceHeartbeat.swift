//
//  DeviceHeartbeat.swift
//  Text it
//
//  Schreibt regelmäßig einen DeviceNode mit aktuellem Zeitstempel.
//  Da dieser Datensatz via CloudKit synct, sehen Mac & iPad einander
//  und können den jeweils anderen Gerätestatus anzeigen.
//

import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class DeviceHeartbeat {
    static let shared = DeviceHeartbeat()

    private let installIDKey = "textit.installID"
    private(set) var installID: String
    private var timer: Timer?
    private weak var context: ModelContext?

    private init() {
        if let saved = UserDefaults.standard.string(forKey: installIDKey) {
            installID = saved
        } else {
            let new = UUID().uuidString
            UserDefaults.standard.set(new, forKey: installIDKey)
            installID = new
        }
    }

    func start(context: ModelContext) {
        self.context = context
        beat()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.beat() }
        }
    }

    func beat() {
        guard let context else { return }
        let id = installID
        let descriptor = FetchDescriptor<DeviceNode>(
            predicate: #Predicate { $0.installID == id }
        )
        let node: DeviceNode
        if let existing = try? context.fetch(descriptor).first {
            node = existing
        } else {
            node = DeviceNode(installID: id)
            context.insert(node)
        }
        node.name = Self.deviceName
        node.platform = Self.platform
        node.systemVersion = Self.systemVersion
        node.lastSeen = Date()
        try? context.save()
    }

    static var deviceName: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #elseif canImport(AppKit)
        return Host.current().localizedName ?? "Mac"
        #else
        return "Gerät"
        #endif
    }

    static var platform: String {
        #if os(macOS)
        return "Mac"
        #elseif os(visionOS)
        return "Vision"
        #elseif os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #else
        return "Unbekannt"
        #endif
    }

    static var systemVersion: String {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #elseif canImport(AppKit)
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        #else
        return ""
        #endif
    }

    static var platformSymbol: String {
        switch platform {
        case "Mac":    return "macbook"
        case "iPad":   return "ipad"
        case "iPhone": return "iphone"
        case "Vision": return "vision.pro"
        default:       return "questionmark.circle"
        }
    }
}
