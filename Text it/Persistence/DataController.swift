//
//  DataController.swift
//  Text it
//
//  Konfiguriert den SwiftData ModelContainer mit automatischer CloudKit-Synchronisation.
//

import Foundation
import SwiftData

enum DataController {
    @MainActor
    static let shared: ModelContainer = {
        let schema = Schema([
            Workspace.self,
            Page.self,
            Block.self,
            DeviceNode.self,
            DailyTodo.self,
            Flashcard.self
        ])

        // CloudKit-Sync: identifier nil => verwendet den ersten iCloud-Container aus den Entitlements
        let config = ModelConfiguration(
            "TextItStore",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .automatic
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            seedIfNeeded(container: container)
            return container
        } catch {
            // Fallback ohne CloudKit (z. B. kein iCloud-Login oder Container nicht erreichbar)
            let fallback = ModelConfiguration(
                "TextItStoreLocal",
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            do {
                let container = try ModelContainer(for: schema, configurations: [fallback])
                seedIfNeeded(container: container)
                return container
            } catch {
                // Letzter Fallback: nur im Arbeitsspeicher (kein Datenverlust möglich, da noch nichts da)
                let memoryFallback = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                let container = (try? ModelContainer(for: schema, configurations: [memoryFallback]))
                    ?? (try! ModelContainer(for: schema))
                seedIfNeeded(container: container)
                return container
            }
        }
    }()

    @MainActor
    private static func seedIfNeeded(container: ModelContainer) {
        let ctx = container.mainContext
        let descriptor = FetchDescriptor<Workspace>()
        if let count = try? ctx.fetchCount(descriptor), count == 0 {
            let ws = Workspace(name: "Mein Workspace", icon: "square.stack.3d.up.fill")
            ctx.insert(ws)

            let welcome = Page(title: "👋 Willkommen", icon: "sparkles", workspace: ws)
            ctx.insert(welcome)

            let blocks: [Block] = [
                {
                    let b = Block(type: .heading, text: "Willkommen bei Smartnote", sortIndex: 0, page: welcome)
                    b.level = 1; return b
                }(),
                Block(type: .text,
                      text: "Eine vollständige Notion-Alternative für macOS & iPad mit iCloud-Sync und Apple Pencil-Unterstützung.",
                      sortIndex: 1, page: welcome),
                {
                    let b = Block(type: .callout,
                                  text: "Tipp: Drücke „/“ um einen neuen Block einzufügen.",
                                  sortIndex: 2, page: welcome)
                    b.emoji = "💡"; return b
                }(),
                {
                    let b = Block(type: .heading, text: "Funktionen", sortIndex: 3, page: welcome)
                    b.level = 2; return b
                }(),
                Block(type: .todo, text: "Verschachtelte Seiten & Ordner", sortIndex: 4, page: welcome),
                Block(type: .todo, text: "Rich-Text-Blöcke, Code, Zitate, Hinweise", sortIndex: 5, page: welcome),
                Block(type: .todo, text: "Apple-Pencil-Handschrift (iPad)", sortIndex: 6, page: welcome),
                Block(type: .todo, text: "Synchronisation per iCloud", sortIndex: 7, page: welcome),
                Block(type: .divider, text: "", sortIndex: 8, page: welcome),
                Block(type: .quote,
                      text: "„Strukturierte Notizen, schön gedacht.“",
                      sortIndex: 9, page: welcome)
            ]
            blocks.forEach { ctx.insert($0) }

            try? ctx.save()
        }
    }
}
