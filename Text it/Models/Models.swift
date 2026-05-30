//
//  Models.swift
//  Text it
//
//  SwiftData-Modelle für Notion-ähnliche Notizen mit CloudKit-Sync.
//  Alle Properties sind optional / haben Defaults (CloudKit-Anforderung).
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Device (für Live-Geräte-Anzeige via CloudKit)

@Model
final class DeviceNode {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var platform: String = ""        // "iPad", "iPhone", "Mac", "Vision"
    var systemVersion: String = ""
    var lastSeen: Date = Date()
    var installID: String = ""       // pro App-Installation eindeutig

    init(id: UUID = UUID(),
         name: String = "",
         platform: String = "",
         systemVersion: String = "",
         lastSeen: Date = Date(),
         installID: String = "") {
        self.id = id
        self.name = name
        self.platform = platform
        self.systemVersion = systemVersion
        self.lastSeen = lastSeen
        self.installID = installID
    }
}

// MARK: - Workspace

@Model
final class Workspace {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = "Mein Workspace"
    var icon: String = "square.stack.3d.up.fill"
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Page.workspace)
    var pages: [Page]? = []

    init(name: String = "Mein Workspace", icon: String = "square.stack.3d.up.fill") {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.createdAt = Date()
    }
}

// MARK: - Page

@Model
final class Page {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String = ""
    var icon: String = "doc.text"
    var coverColorHex: String? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var sortIndex: Int = 0
    var isFavorite: Bool = false
    var isTrashed: Bool = false
    /// Soft-Delete: verhindert CloudKit-Restore nach "Endgültig löschen".
    /// Seiten mit diesem Flag werden in ALLEN Queries ausgeblendet.
    var isPermanentlyDeleted: Bool = false
    var isExpanded: Bool = true

    // Hierarchie
    var parent: Page? = nil
    @Relationship(deleteRule: .cascade, inverse: \Page.parent)
    var children: [Page]? = []

    // Workspace
    var workspace: Workspace? = nil

    // Blöcke
    @Relationship(deleteRule: .cascade, inverse: \Block.page)
    var blocks: [Block]? = []

    // Tags
    var tagsData: Data? = nil

    /// Seitenweite Apple-Pencil-Handschrift (überlagert ALLE Blöcke).
    var drawingData: Data? = nil

    /// Seite ist ein Ordner (kein Inhalt-Editor, nur Kinder-Container).
    var isFolder: Bool = false

    init(title: String = "Unbenannt",
         icon: String = "doc.text",
         parent: Page? = nil,
         workspace: Workspace? = nil,
         isFolder: Bool = false) {
        self.id = UUID()
        self.title = title
        self.icon = icon
        self.parent = parent
        self.workspace = workspace
        self.isFolder = isFolder
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var sortedChildren: [Page] {
        (children ?? [])
            .filter { !$0.isTrashed }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Alle Blöcke nach sortIndex (für Snapshots, Migration etc.)
    var sortedBlocks: [Block] {
        (blocks ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Nur Blöcke ohne übergeordneten Toggle-Block – für den PageEditor.
    var sortedTopLevelBlocks: [Block] {
        (blocks ?? [])
            .filter { $0.parentBlockID == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Kindblöcke eines bestimmten Toggle-Blocks.
    func sortedChildBlocks(parentID: UUID) -> [Block] {
        (blocks ?? [])
            .filter { $0.parentBlockID == parentID }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    var tags: [String] {
        get {
            guard let d = tagsData,
                  let arr = try? JSONDecoder().decode([String].self, from: d) else { return [] }
            return arr
        }
        set {
            tagsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Gesamtwortanzahl über alle Blöcke.
    var wordCount: Int {
        (blocks ?? []).reduce(0) { count, block in
            count + block.text.split { $0.isWhitespace }.count
        }
    }
}

// MARK: - Block

@Model
final class Block {
    @Attribute(.unique) var id: UUID = UUID()
    var rawType: String = BlockType.text.rawValue
    var text: String = ""
    var sortIndex: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Generische Daten je nach Typ
    var checked: Bool = false           // todo
    var expanded: Bool = true           // toggle
    var level: Int = 1                  // heading 1/2/3
    var language: String = "swift"      // code
    var colorHex: String? = nil         // callout / highlight
    var emoji: String = "💡"            // callout
    var imageData: Data? = nil          // image
    var pdfData: Data? = nil            // PDF-Dokument
    var drawingData: Data? = nil        // PencilKit handwriting
    var numberValue: Double = 0         // table / generic
    var imageWidth: Double = 1.0        // Bildbreite als Anteil der verfügbaren Breite (0.1–1.0)
    var pdfBlockHeight: Double = 700    // Höhe des PDF-Blocks in Punkten (resizable)
    var url: String? = nil              // link / bookmark
    var jsonPayload: Data? = nil        // tables, embeds etc.

    /// UUID des übergeordneten Toggle-Blocks (nil = Top-Level-Block).
    var parentBlockID: UUID? = nil

    /// UUID der verlinkten Seite (für .pagelink-Blöcke).
    var linkedPageID: UUID? = nil

    var page: Page? = nil

    init(type: BlockType = .text,
         text: String = "",
         sortIndex: Int = 0,
         page: Page? = nil) {
        self.id = UUID()
        self.rawType = type.rawValue
        self.text = text
        self.sortIndex = sortIndex
        self.page = page
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var type: BlockType {
        get { BlockType(rawValue: rawType) ?? .text }
        set { rawType = newValue.rawValue }
    }
}

// MARK: - Flashcard

@Model
final class Flashcard {
    @Attribute(.unique) var id: UUID = UUID()
    var front: String = ""
    var back: String = ""
    var deck: String = "Standard"
    // SM-2 spaced repetition
    var easeFactor: Double = 2.5
    var interval: Int = 0        // days until next review
    var repetitions: Int = 0
    var dueDate: Date = Date()
    var createdAt: Date = Date()
    var sourceBlockID: UUID? = nil

    init(front: String, back: String = "", deck: String = "Standard") {
        self.id = UUID()
        self.front = front
        self.back = back
        self.deck = deck
        self.dueDate = Date()
        self.createdAt = Date()
    }

    var isDue: Bool { dueDate <= Date() }

    func applyRating(_ rating: FlashcardRating) {
        switch rating {
        case .again:
            repetitions = 0
            interval = 1
            easeFactor = max(1.3, easeFactor - 0.2)
        case .hard:
            interval = repetitions == 0 ? 1 : max(1, Int((Double(interval) * 1.2).rounded()))
            easeFactor = max(1.3, easeFactor - 0.15)
            repetitions += 1
        case .good:
            if repetitions == 0 { interval = 1 }
            else if repetitions == 1 { interval = 6 }
            else { interval = max(1, Int((Double(interval) * easeFactor).rounded())) }
            repetitions += 1
        case .easy:
            if repetitions == 0 { interval = 4 }
            else if repetitions == 1 { interval = 8 }
            else { interval = max(1, Int((Double(interval) * easeFactor * 1.3).rounded())) }
            easeFactor = min(3.0, easeFactor + 0.15)
            repetitions += 1
        }
        dueDate = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
    }
}

enum FlashcardRating {
    case again, hard, good, easy

    var label: String {
        switch self {
        case .again: return "Nochmal"
        case .hard:  return "Schwer"
        case .good:  return "Gut"
        case .easy:  return "Leicht"
        }
    }

    var color: Color {
        switch self {
        case .again: return .red
        case .hard:  return .orange
        case .good:  return .blue
        case .easy:  return .green
        }
    }
}

// MARK: - DailyTodo

@Model
final class DailyTodo {
    @Attribute(.unique) var id: UUID = UUID()
    var text: String = ""
    var isChecked: Bool = false
    /// Normiert auf Tagesbeginn (00:00:00). Todos mit vergangenen Daten werden
    /// beim App-Start auf „heute" übertragen, wenn sie nicht abgehakt wurden.
    var targetDate: Date = Date()
    var sortIndex: Int = 0
    var carriedOver: Bool = false

    init(text: String = "") {
        self.id = UUID()
        self.text = text
        self.isChecked = false
        self.targetDate = Calendar.current.startOfDay(for: Date())
        self.sortIndex = 0
        self.carriedOver = false
    }
}

extension Date {
    static var today: Date { Calendar.current.startOfDay(for: Date()) }
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var isToday: Bool { Calendar.current.isDateInToday(self) }
}

// MARK: - BlockType

enum BlockType: String, Codable, CaseIterable, Identifiable {
    case text
    case heading
    case todo
    case bullet
    case numbered
    case toggle
    case quote
    case callout
    case code
    case divider
    case image
    case handwriting
    case bookmark
    case table
    case pagelink       // Link zu einer anderen Seite
    case highlight      // Farbig hinterlegter Text (Markierung)
    case equation       // Mathe-/Formelblock (Monospace mit Rand)
    case definition     // Begriff + Definition (Glossar-Stil)
    case pdf            // PDF-Dokument mit Apple-Pencil-Annotationen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text:        return "Text"
        case .heading:     return "Überschrift"
        case .todo:        return "To-do"
        case .bullet:      return "Aufzählung"
        case .numbered:    return "Nummerierte Liste"
        case .toggle:      return "Umschalter"
        case .quote:       return "Zitat"
        case .callout:     return "Hinweis"
        case .code:        return "Code"
        case .divider:     return "Trennlinie"
        case .image:       return "Bild"
        case .handwriting: return "Handschrift (Apple Pencil)"
        case .bookmark:    return "Lesezeichen"
        case .table:       return "Tabelle"
        case .pagelink:    return "Seitenlink"
        case .highlight:   return "Markierung"
        case .equation:    return "Formel / Gleichung"
        case .definition:  return "Definition"
        case .pdf:         return "PDF"
        }
    }

    var systemImage: String {
        switch self {
        case .text:        return "text.alignleft"
        case .heading:     return "textformat.size"
        case .todo:        return "checkmark.square"
        case .bullet:      return "list.bullet"
        case .numbered:    return "list.number"
        case .toggle:      return "chevron.right.circle"
        case .quote:       return "quote.opening"
        case .callout:     return "lightbulb"
        case .code:        return "chevron.left.forwardslash.chevron.right"
        case .divider:     return "minus"
        case .image:       return "photo"
        case .handwriting: return "pencil.tip.crop.circle"
        case .bookmark:    return "bookmark"
        case .table:       return "tablecells"
        case .pagelink:    return "link"
        case .highlight:   return "highlighter"
        case .equation:    return "function"
        case .definition:  return "character.book.closed"
        case .pdf:         return "doc.richtext"
        }
    }

    var shortcut: String {
        switch self {
        case .text:        return ""
        case .heading:     return "#"
        case .todo:        return "[]"
        case .bullet:      return "-"
        case .numbered:    return "1."
        case .toggle:      return ">"
        case .quote:       return "> >"
        case .callout:     return "!"
        case .code:        return "```"
        case .divider:     return "---"
        case .image:       return ""
        case .handwriting: return ""
        case .bookmark:    return ""
        case .table:       return ""
        case .pagelink:    return "@"
        case .highlight:   return "=="
        case .equation:    return "$$"
        case .definition:  return ":"
        case .pdf:         return ""
        }
    }
}
