//
//  Text_itApp.swift
//  Text it
//

import SwiftUI
import SwiftData

@main
struct Text_itApp: App {
    @State private var appState = AppState()
    @AppStorage("appearance") private var appearance: String = "system"

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .tint(appState.theme.accent)
                .preferredColorScheme(colorScheme)
                .onAppear {
                    let ctx = DataController.shared.mainContext
                    NearbySync.shared.start(context: ctx)
                }
        }
        .modelContainer(DataController.shared)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Neue Seite") {
                    NotificationCenter.default.post(name: .createNewPage, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Suche…") {
                    NotificationCenter.default.post(name: .openSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(appState)
        }
        .modelContainer(DataController.shared)
        #endif
    }
}

extension Notification.Name {
    static let createNewPage = Notification.Name("textit.createNewPage")
    static let openSearch    = Notification.Name("textit.openSearch")
}
