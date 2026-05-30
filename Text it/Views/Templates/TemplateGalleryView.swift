//
//  TemplateGalleryView.swift
//  Text it
//
//  Vorlagengalerie: 10 vorgefertigte Seitenvorlagen.
//

import SwiftUI
import SwiftData

// MARK: - Template-Datenmodell

struct TemplateBlock {
    var type: BlockType
    var text: String
    var level: Int = 1
    var checked: Bool = false
}

struct PageTemplate: Identifiable {
    let id: String
    let title: String
    let icon: String
    let description: String
    let color: Color
    let category: Category
    let blocks: [TemplateBlock]

    enum Category: String, CaseIterable {
        case all       = "Alle"
        case daily     = "Täglich"
        case work      = "Arbeit"
        case learning  = "Lernen"
        case creative  = "Kreativ"
    }
}

// MARK: - Vorlagen-Bibliothek

private let templates: [PageTemplate] = [
    PageTemplate(
        id: "daily-journal",
        title: "Tagesjournal",
        icon: "book.closed.fill",
        description: "Dankbarkeit, Reflexion und Tagesvorsätze",
        color: .orange,
        category: .daily,
        blocks: [
            TemplateBlock(type: .heading, text: "Datum & Stimmung", level: 2),
            TemplateBlock(type: .text, text: ""),
            TemplateBlock(type: .heading, text: "Dankbarkeit", level: 2),
            TemplateBlock(type: .bullet, text: "Ich bin dankbar für…"),
            TemplateBlock(type: .bullet, text: ""),
            TemplateBlock(type: .bullet, text: ""),
            TemplateBlock(type: .heading, text: "Reflexion", level: 2),
            TemplateBlock(type: .text, text: "Was war heute bedeutsam?"),
            TemplateBlock(type: .heading, text: "Ziele für morgen", level: 2),
            TemplateBlock(type: .todo, text: ""),
            TemplateBlock(type: .todo, text: ""),
            TemplateBlock(type: .todo, text: ""),
        ]
    ),
    PageTemplate(
        id: "meeting-notes",
        title: "Meeting-Notizen",
        icon: "person.3.fill",
        description: "Agenda, Teilnehmer, Ergebnisse und nächste Schritte",
        color: .blue,
        category: .work,
        blocks: [
            TemplateBlock(type: .callout, text: "Meeting-Datum und Uhrzeit hier eintragen"),
            TemplateBlock(type: .heading, text: "Agenda", level: 2),
            TemplateBlock(type: .bullet, text: ""),
            TemplateBlock(type: .heading, text: "Teilnehmer", level: 2),
            TemplateBlock(type: .bullet, text: ""),
            TemplateBlock(type: .heading, text: "Notizen", level: 2),
            TemplateBlock(type: .text, text: ""),
            TemplateBlock(type: .heading, text: "Entscheidungen", level: 2),
            TemplateBlock(type: .bullet, text: ""),
            TemplateBlock(type: .heading, text: "Nächste Schritte", level: 2),
            TemplateBlock(type: .todo, text: ""),
            TemplateBlock(type: .todo, text: ""),
        ]
    ),
    PageTemplate(
        id: "project-plan",
        title: "Projektplan",
        icon: "list.bullet.clipboard.fill",
        description: "Ziele, Meilensteine, Aufgaben und Ressourcen",
        color: .purple,
        category: .work,
        blocks: [
            TemplateBlock(type: .heading, text: "Projektüberblick", level: 2),
            TemplateBlock(type: .text, text: "Kurze Beschreibung des Projekts"),
            TemplateBlock(type: .heading, text: "Ziele", level: 2),
            TemplateBlock(type: .bullet, text: "Hauptziel"),
            TemplateBlock(type: .heading, text: "Meilensteine", level: 2),
            TemplateBlock(type: .numbered, text: ""),
            TemplateBlock(type: .numbered, text: ""),
            TemplateBlock(type: .heading, text: "Aufgaben", level: 2),
            TemplateBlock(type: .todo, text: ""),
            TemplateBlock(type: .todo, text: ""),
            TemplateBlock(type: .todo, text: ""),
            TemplateBlock(type: .heading, text: "Ressourcen & Links", level: 2),
            TemplateBlock(type: .bullet, text: ""),
        ]
    ),
    PageTemplate(
        id: "study-notes",
        title: "Lernnotizen",
        icon: "graduationcap.fill",
        description: "Schlüsselkonzepte, Zusammenfassung und Testfragen",
        color: .green,
        category: .learning,
        blocks: [
            TemplateBlock(type: .heading, text: "Thema", level: 2),
            TemplateBlock(type: .text, text: "Fach und Datum"),
            TemplateBlock(type: .heading, text: "Schlüsselkonzepte", level: 2),
            TemplateBlock(type: .bullet, text: ""),
            TemplateBlock(type: .bullet, text: ""),
            TemplateBlock(type: .heading, text: "Detailnotizen", level: 2),
            TemplateBlock(type: .text, text: ""),
            TemplateBlock(type: .heading, text: "Zusammenfassung", level: 2),
            TemplateBlock(type: .quote, text: "Wichtigstes in 3 Sätzen"),
            TemplateBlock(type: .heading, text: "Prüfungsfragen", level: 2),
            TemplateBlock(type: .todo, text: "Frage 1"),
            TemplateBlock(type: .todo, text: "Frage 2"),
        ]
    ),
    PageTemplate(
        id: "book-summary",
        title: "Buchzusammenfassung",
        icon: "books.vertical.fill",
        description: "Kernaussagen, Zitate und persönliche Reflexion",
        color: .brown,
        category: .learning,
        blocks: [
            TemplateBlock(type: .callout, text: "Autor · Erscheinungsjahr · Genre"),
            TemplateBlock(type: .heading, text: "Worum geht es?", level: 2),
            TemplateBlock(type: .text, text: "Kurzzusammenfassung in 2–3 Sätzen"),
            TemplateBlock(type: .heading, text: "Kernaussagen", level: 2),
            TemplateBlock(type: .numbered, text: ""),
            TemplateBlock(type: .numbered, text: ""),
            TemplateBlock(type: .numbered, text: ""),
            TemplateBlock(type: .heading, text: "Lieblingsszene", level: 2),
            TemplateBlock(type: .quote, text: ""),
            TemplateBlock(type: .heading, text: "Meine Gedanken", level: 2),
            TemplateBlock(type: .text, text: "Was nehme ich mit?"),
            TemplateBlock(type: .heading, text: "Bewertung", level: 2),
            TemplateBlock(type: .text, text: "⭐⭐⭐⭐⭐"),
        ]
    ),
    PageTemplate(
        id: "brainstorming",
        title: "Brainstorming",
        icon: "brain.fill",
        description: "Ideen sammeln, sortieren und priorisieren",
        color: .pink,
        category: .creative,
        blocks: [
            TemplateBlock(type: .callout, text: "Was ist die Frage / das Problem?"),
            TemplateBlock(type: .heading, text: "Alle Ideen (unkritisch)", level: 2),
            TemplateBlock(type: .bullet, text: ""),
            TemplateBlock(type: .bullet, text: ""),
            TemplateBlock(type: .bullet, text: ""),
            TemplateBlock(type: .heading, text: "Top-Ideen", level: 2),
            TemplateBlock(type: .numbered, text: ""),
            TemplateBlock(type: .numbered, text: ""),
            TemplateBlock(type: .heading, text: "Nächste Schritte", level: 2),
            TemplateBlock(type: .todo, text: ""),
            TemplateBlock(type: .todo, text: ""),
        ]
    ),
    PageTemplate(
        id: "weekly-review",
        title: "Wochenrückblick",
        icon: "chart.line.uptrend.xyaxis",
        description: "Erfolge, Herausforderungen und Fokus der nächsten Woche",
        color: .teal,
        category: .daily,
        blocks: [
            TemplateBlock(type: .callout, text: "KW  ·  Datum – Datum"),
            TemplateBlock(type: .heading, text: "Erfolge dieser Woche", level: 2),
            TemplateBlock(type: .bullet, text: ""),
            TemplateBlock(type: .heading, text: "Herausforderungen", level: 2),
            TemplateBlock(type: .bullet, text: ""),
            TemplateBlock(type: .heading, text: "Was habe ich gelernt?", level: 2),
            TemplateBlock(type: .text, text: ""),
            TemplateBlock(type: .heading, text: "Fokus nächste Woche", level: 2),
            TemplateBlock(type: .todo, text: "Priorität 1"),
            TemplateBlock(type: .todo, text: "Priorität 2"),
            TemplateBlock(type: .todo, text: "Priorität 3"),
        ]
    ),
    PageTemplate(
        id: "recipe",
        title: "Rezept",
        icon: "fork.knife",
        description: "Zutaten, Anleitung und persönliche Notizen",
        color: .red,
        category: .daily,
        blocks: [
            TemplateBlock(type: .callout, text: "🕐 Zubereitungszeit · 👤 Portionen"),
            TemplateBlock(type: .heading, text: "Zutaten", level: 2),
            TemplateBlock(type: .bullet, text: ""),
            TemplateBlock(type: .bullet, text: ""),
            TemplateBlock(type: .heading, text: "Zubereitung", level: 2),
            TemplateBlock(type: .numbered, text: ""),
            TemplateBlock(type: .numbered, text: ""),
            TemplateBlock(type: .numbered, text: ""),
            TemplateBlock(type: .heading, text: "Tipps & Variationen", level: 2),
            TemplateBlock(type: .text, text: ""),
        ]
    ),
    PageTemplate(
        id: "code-review",
        title: "Code-Review",
        icon: "chevron.left.forwardslash.chevron.right",
        description: "Pull-Request-Notizen, Befunde und Kommentare",
        color: .indigo,
        category: .work,
        blocks: [
            TemplateBlock(type: .callout, text: "PR-Titel · Autor · Datum"),
            TemplateBlock(type: .heading, text: "Änderungen", level: 2),
            TemplateBlock(type: .bullet, text: ""),
            TemplateBlock(type: .heading, text: "Offene Fragen", level: 2),
            TemplateBlock(type: .todo, text: ""),
            TemplateBlock(type: .heading, text: "Gefundene Probleme", level: 2),
            TemplateBlock(type: .bullet, text: ""),
            TemplateBlock(type: .heading, text: "Positives", level: 2),
            TemplateBlock(type: .bullet, text: ""),
            TemplateBlock(type: .heading, text: "Fazit", level: 2),
            TemplateBlock(type: .text, text: "Approved / Changes requested"),
        ]
    ),
    PageTemplate(
        id: "habit-tracker",
        title: "Habit Tracker",
        icon: "checkmark.seal.fill",
        description: "Tägliche Gewohnheiten und Fortschritt verfolgen",
        color: .cyan,
        category: .daily,
        blocks: [
            TemplateBlock(type: .heading, text: "Meine Gewohnheiten", level: 2),
            TemplateBlock(type: .todo, text: "Sport / Bewegung"),
            TemplateBlock(type: .todo, text: "Lesen (30 Min.)"),
            TemplateBlock(type: .todo, text: "Meditieren"),
            TemplateBlock(type: .todo, text: "Ausreichend Wasser"),
            TemplateBlock(type: .todo, text: "Früh ins Bett"),
            TemplateBlock(type: .heading, text: "Reflexion", level: 2),
            TemplateBlock(type: .text, text: "Was lief gut? Was kann ich verbessern?"),
        ]
    ),
]

// MARK: - TemplateGalleryView

struct TemplateGalleryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    @Query private var workspaces: [Workspace]

    @State private var selectedCategory: PageTemplate.Category = .all
    @State private var hoveredTemplate: String? = nil

    private var filtered: [PageTemplate] {
        selectedCategory == .all ? templates : templates.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                headerSection

                // Kategorie-Filter
                categoryFilter

                // Template-Grid
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 16)
                    ],
                    spacing: 16
                ) {
                    ForEach(filtered) { template in
                        TemplateCard(template: template, isHovered: hoveredTemplate == template.id) {
                            createPage(from: template)
                        }
                        .onHover { hoveredTemplate = $0 ? template.id : nil }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .navigationTitle("Vorlagen")
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vorlagen")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("Starte mit einer vorgefertigten Struktur")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PageTemplate.Category.allCases, id: \.rawValue) { cat in
                    CategoryChip(
                        title: cat.rawValue,
                        isSelected: selectedCategory == cat
                    ) {
                        withAnimation(.spring(response: 0.25)) { selectedCategory = cat }
                    }
                }
            }
        }
    }

    private func createPage(from template: PageTemplate) {
        guard let ws = workspaces.first else { return }
        let actions = PageActions(context: context)
        let page = actions.createPage(in: ws, title: template.title)
        page.icon = template.icon

        var idx = 0
        for tb in template.blocks {
            let block = actions.addBlock(to: page, type: tb.type, text: tb.text)
            block.level = tb.level
            block.checked = tb.checked
            block.sortIndex = idx
            idx += 1
        }
        try? context.save()
        appState.navigateTo(pageID: page.id)
    }
}

// MARK: - TemplateCard

struct TemplateCard: View {
    let template: PageTemplate
    let isHovered: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Icon
                Image(systemName: template.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(template.color)
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(template.color.opacity(0.14))
                    )

                // Title + Description
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(template.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Block-Vorschau
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(template.blocks.prefix(4).enumerated()), id: \.offset) { _, b in
                        HStack(spacing: 5) {
                            Image(systemName: b.type.systemImage)
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                            Text(b.text.isEmpty ? b.type.title : b.text)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    if template.blocks.count > 4 {
                        Text("+ \(template.blocks.count - 4) weitere Blöcke")
                            .font(.system(size: 9))
                            .foregroundStyle(.quaternary)
                    }
                }
                .padding(.top, 4)

                Spacer(minLength: 0)

                // Verwenden-Button
                Label("Verwenden", systemImage: "arrow.right.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(template.color)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.quaternary.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isHovered ? template.color.opacity(0.5) : Color.clear, lineWidth: 1.5)
                    )
            )
            .shadow(color: isHovered ? template.color.opacity(0.12) : .clear, radius: 12, y: 4)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.25), value: isHovered)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CategoryChip

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }
}
