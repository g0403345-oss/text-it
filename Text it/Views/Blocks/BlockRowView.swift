//
//  BlockRowView.swift
//  Text it
//

import SwiftUI
import SwiftData

struct BlockRowView: View {
    @Bindable var block: Block
    var onEnter: (Block) -> Void
    var onDelete: (Block) -> Void
    var onSlash: (Block) -> Void
    var onChangeType: (Block, BlockType) -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var hovering: Bool = false
    @State private var showPagePicker: Bool = false
    @State private var showAddFlashcard: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // Handle / Plus
            VStack(spacing: 2) {
                Button {
                    onSlash(block)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .opacity(hovering ? 1 : 0.2)

                Menu {
                    blockMenu
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }
                .menuStyle(.borderlessButton)
                .opacity(hovering ? 1 : 0.2)
            }
            .frame(width: 24)
            .padding(.top, 4)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onHover { hovering = $0 }
        .contentShape(Rectangle())
        // Timestamp bei Texteingabe aktualisieren damit Last-Write-Wins korrekt funktioniert
        .onChange(of: block.text) { _, _ in
            // Skip if this change came from a remote apply — avoids echoing it back.
            let nearby = NearbySync.shared
            if let remoteTS = nearby.remoteAppliedBlockTimestamps[block.id],
               remoteTS == block.updatedAt {
                nearby.remoteAppliedBlockTimestamps.removeValue(forKey: block.id)
                return
            }
            block.updatedAt = Date()
            block.page?.updatedAt = Date()
            try? context.save()
            nearby.sendBlockUpsert(block)
        }
        .sheet(isPresented: $showAddFlashcard) {
            let parts = block.text.components(separatedBy: "::")
            let term = parts.first ?? ""
            let def  = parts.count > 1 ? parts.dropFirst().joined(separator: "::") : ""
            FlashcardFromBlockSheet(front: term.trimmingCharacters(in: .whitespaces),
                                   back: def.trimmingCharacters(in: .whitespaces))
        }
    }

    @ViewBuilder
    private var blockMenu: some View {
        Menu("In Typ ändern") {
            ForEach(BlockType.allCases) { t in
                Button {
                    onChangeType(block, t)
                } label: {
                    Label(t.title, systemImage: t.systemImage)
                }
            }
        }
        Button("Nach oben verschieben") { PageActions(context: context).moveBlock(block, up: true) }
        Button("Nach unten verschieben") { PageActions(context: context).moveBlock(block, up: false) }
        Divider()
        if block.type == .definition {
            Button("Als Lernkarte speichern", systemImage: "rectangle.on.rectangle.angled") {
                showAddFlashcard = true
            }
            Divider()
        }
        if block.drawingData != nil {
            Button("Handschrift löschen", systemImage: "eraser") {
                block.drawingData = nil
                try? context.save()
            }
        }
        Button("Löschen", role: .destructive) {
            onDelete(block)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch block.type {
        case .text:        textBlock
        case .heading:     headingBlock
        case .todo:        todoBlock
        case .bullet:      bulletBlock(symbol: "•")
        case .numbered:    bulletBlock(symbol: nextNumberLabel())
        case .toggle:      toggleBlock
        case .quote:       quoteBlock
        case .callout:     calloutBlock
        case .code:        codeBlock
        case .divider:     Divider().padding(.vertical, 8)
        case .image:       ImageBlockView(block: block)
        case .pdf:         PDFBlockView(block: block)
        case .handwriting: HandwritingBlockView(block: block)
        case .bookmark:    bookmarkBlock
        case .table:       tableBlock
        case .pagelink:    pagelinkBlock
        case .highlight:   highlightBlock
        case .equation:    equationBlock
        case .definition:  definitionBlock
        }
    }

    // MARK: - Text

    private var textBlock: some View {
        EditableTextField(
            text: $block.text,
            placeholder: "Tippe / f\u{FC}r Befehle",
            font: .body,
            uiFontSize: 17,
            uiFontWeight: .regular,
            onEnter: { onEnter(block) },
            onBackspaceEmpty: { onDelete(block) },
            onSlash: { onSlash(block) },
            onMarkdownShortcut: { type, level in
                onChangeType(block, type)
                block.level = level
                save()
            }
        )
    }

    // MARK: - Heading

    private var headingBlock: some View {
        HStack {
            Menu {
                Button("H1") { block.level = 1; save() }
                Button("H2") { block.level = 2; save() }
                Button("H3") { block.level = 3; save() }
            } label: {
                Text("H\(block.level)").font(.caption).foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)

            EditableTextField(
                text: $block.text,
                placeholder: "Überschrift",
                font: headingFont,
                uiFontSize: headingSize,
                uiFontWeight: headingWeight,
                onEnter: { onEnter(block) },
                onBackspaceEmpty: { onDelete(block) },
                onSlash: { onSlash(block) }
            )
        }
    }

    private var headingFont: Font {
        switch block.level {
        case 1: return .system(size: 28, weight: .bold)
        case 2: return .system(size: 22, weight: .semibold)
        default: return .system(size: 18, weight: .semibold)
        }
    }

    private var headingSize: CGFloat {
        switch block.level { case 1: return 28; case 2: return 22; default: return 18 }
    }

    private var headingWeight: PlatformFontWeight {
        switch block.level { case 1: return .bold; default: return .semibold }
    }

    // MARK: - Todo

    private var todoBlock: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                block.checked.toggle(); save()
            } label: {
                Image(systemName: block.checked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(block.checked ? Color.accentColor : Color.secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)
            .padding(.top, 3)

            EditableTextField(
                text: $block.text,
                placeholder: "To-do",
                font: .body,
                strikethrough: block.checked,
                onEnter: { onEnter(block) },
                onBackspaceEmpty: { onDelete(block) },
                onSlash: { onSlash(block) }
            )
        }
    }

    // MARK: - Bullet / Numbered

    private func bulletBlock(symbol: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(symbol)
                .frame(minWidth: 18, alignment: .trailing)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            EditableTextField(
                text: $block.text,
                placeholder: "Listenpunkt",
                font: .body,
                onEnter: { onEnter(block) },
                onBackspaceEmpty: { onDelete(block) },
                onSlash: { onSlash(block) }
            )
        }
    }

    private func nextNumberLabel() -> String {
        guard let page = block.page else { return "1." }
        let sorted = page.sortedTopLevelBlocks
        var n = 1
        for b in sorted {
            if b.id == block.id { return "\(n)." }
            if b.type == .numbered { n += 1 } else { n = 1 }
        }
        return "\(n)."
    }

    // MARK: - Toggle (echte Kindblöcke)

    private var toggleBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header-Zeile
            HStack(alignment: .top, spacing: 6) {
                Button {
                    block.expanded.toggle(); save()
                } label: {
                    Image(systemName: block.expanded ? "chevron.down" : "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                EditableTextField(
                    text: $block.text,
                    placeholder: "Umschalter",
                    font: .body.weight(.medium),
                    onEnter: {
                        // Enter im Header öffnet/erstellt erstes Kind
                        guard let page = block.page else { return }
                        if !block.expanded { block.expanded = true; save() }
                        PageActions(context: context).addBlock(
                            to: page, type: .text, after: nil,
                            parentBlockID: block.id)
                    },
                    onBackspaceEmpty: { onDelete(block) },
                    onSlash: { onSlash(block) }
                )
            }

            // Kinder
            if block.expanded {
                let children = block.page?.sortedChildBlocks(parentID: block.id) ?? []
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(children) { child in
                        BlockRowView(
                            block: child,
                            onEnter: { current in
                                guard let page = block.page else { return }
                                PageActions(context: context).addBlock(
                                    to: page, type: .text, after: current,
                                    parentBlockID: block.id)
                            },
                            onDelete: { b in
                                PageActions(context: context).deleteBlock(b)
                            },
                            onSlash: { b in onSlash(b) },
                            onChangeType: { b, t in onChangeType(b, t) }
                        )
                    }

                    // "+ Block hinzufügen" innerhalb des Toggles
                    Button {
                        guard let page = block.page else { return }
                        PageActions(context: context).addBlock(
                            to: page, type: .text,
                            after: children.last, parentBlockID: block.id)
                    } label: {
                        Label("Block hinzufügen", systemImage: "plus")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                .padding(.leading, 22)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Quote

    private var quoteBlock: some View {
        HStack(spacing: 10) {
            Rectangle().fill(.secondary).frame(width: 3)
            EditableTextField(
                text: $block.text,
                placeholder: "Zitat",
                font: .system(.body, design: .serif).italic(),
                onEnter: { onEnter(block) },
                onBackspaceEmpty: { onDelete(block) },
                onSlash: { onSlash(block) }
            )
        }
    }

    // MARK: - Callout

    private var calloutBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            Menu(block.emoji) {
                ForEach(["💡","⚠️","ℹ️","✅","🔥","📌","❤️","⭐️","🎯","💬","🚀","🔑"], id: \.self) { e in
                    Button(e) { block.emoji = e; save() }
                }
            }
            .menuStyle(.borderlessButton)

            EditableTextField(
                text: $block.text,
                placeholder: "Hinweis",
                font: .body,
                onEnter: { onEnter(block) },
                onBackspaceEmpty: { onDelete(block) },
                onSlash: { onSlash(block) }
            )
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Code

    private var codeBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Menu(block.language) {
                    ForEach(["swift","python","javascript","typescript","rust","go","kotlin",
                             "java","html","css","sql","bash","markdown","plaintext"], id: \.self) { lang in
                        Button(lang) { block.language = lang; save() }
                    }
                }
                .menuStyle(.borderlessButton)
                .font(.caption)
                Spacer()
                Button {
                    #if os(iOS)
                    UIPasteboard.general.string = block.text
                    #else
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(block.text, forType: .string)
                    #endif
                } label: {
                    Image(systemName: "doc.on.doc").font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            EditableTextField(
                text: $block.text,
                placeholder: "Code",
                font: .system(.body, design: .monospaced),
                multiline: true,
                onEnter: { onEnter(block) },
                onBackspaceEmpty: { onDelete(block) },
                onSlash: { onSlash(block) }
            )
            .padding(10)
            .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
        }
    }

    // MARK: - Bookmark

    private var bookmarkBlock: some View {
        HStack {
            Image(systemName: "link")
            TextField("https://…", text: Binding(
                get: { block.url ?? "" },
                set: { block.url = $0; save() }
            ))
            .textFieldStyle(.plain)
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Table

    private var tableBlock: some View {
        TableBlockView(block: block)
    }

    // MARK: - Page Link

    private var pagelinkBlock: some View {
        Group {
            if let linkedID = block.linkedPageID {
                // Verlinkte Seite anzeigen
                let page = fetchLinkedPage(linkedID)
                Button {
                    appState.navigateTo(pageID: linkedID)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: page?.icon ?? "link")
                            .frame(width: 24, height: 24)
                            .background(Color.accentColor.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(Color.accentColor)
                        Text(page?.title.isEmpty == false ? page!.title : "Unbenannt")
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                        Image(systemName: "arrow.right.circle")
                            .foregroundStyle(Color.accentColor.opacity(0.6))
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Andere Seite verlinken") { showPagePicker = true }
                    Button("Link entfernen", role: .destructive) {
                        block.linkedPageID = nil; save()
                    }
                }
            } else {
                // Noch keine Seite ausgewählt
                Button { showPagePicker = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "link.badge.plus")
                        Text("Seite verlinken…")
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showPagePicker) {
            PagePickerSheet { pickedID in
                block.linkedPageID = pickedID
                save()
            } onCreate: {
                // Neue Seite erstellen und verlinken
                guard let ws = block.page?.workspace else { return }
                let newPage = PageActions(context: context).createPage(in: ws)
                block.linkedPageID = newPage.id
                save()
            }
        }
    }

    private func fetchLinkedPage(_ id: UUID) -> Page? {
        let targetID = id
        return try? context.fetch(
            FetchDescriptor<Page>(predicate: #Predicate { $0.id == targetID })
        ).first
    }

    // MARK: - Highlight (farbig hinterlegter Text)

    private var highlightBlock: some View {
        @Bindable var state = appState
        return EditableTextField(
            text: $block.text,
            placeholder: "Markierter Text",
            font: .body,
            onEnter: { onEnter(block) },
            onBackspaceEmpty: { onDelete(block) },
            onSlash: { onSlash(block) },
            onMarkdownShortcut: { type, level in onChangeType(block, type); block.level = level; save() }
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(appState.theme.accent.opacity(0.18))
        )
    }

    // MARK: - Equation (Formel/Gleichung)

    private var equationBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "function")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Formel")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            EditableTextField(
                text: $block.text,
                placeholder: "f(x) = …",
                font: .system(.body, design: .monospaced),
                uiFontSize: 16,
                multiline: true,
                onEnter: { onEnter(block) },
                onBackspaceEmpty: { onDelete(block) },
                onSlash: { onSlash(block) }
            )
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.indigo.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.indigo.opacity(0.25), lineWidth: 1))
            )
        }
    }

    // MARK: - Definition (Begriff + Erklärung)

    private var definitionBlock: some View {
        HStack(alignment: .top, spacing: 0) {
            // Begriff links (fett, Akzentfarbe)
            EditableTextField(
                text: Binding(
                    get: { block.text.components(separatedBy: "::").first ?? block.text },
                    set: { newTerm in
                        let parts = block.text.components(separatedBy: "::")
                        let def = parts.count > 1 ? parts[1] : ""
                        block.text = newTerm + "::" + def
                        save()
                    }
                ),
                placeholder: "Begriff",
                font: .body.weight(.semibold),
                uiFontSize: 17,
                uiFontWeight: .semibold,
                onEnter: { onEnter(block) },
                onBackspaceEmpty: { onDelete(block) },
                onSlash: { onSlash(block) }
            )
            .foregroundStyle(appState.theme.accent)
            .frame(minWidth: 120, maxWidth: 180)

            Text("  —  ")
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            // Definition rechts
            EditableTextField(
                text: Binding(
                    get: { block.text.components(separatedBy: "::").dropFirst().joined(separator: "::") },
                    set: { newDef in
                        let term = block.text.components(separatedBy: "::").first ?? ""
                        block.text = term + "::" + newDef
                        save()
                    }
                ),
                placeholder: "Erklärung",
                font: .body,
                uiFontSize: 17,
                onEnter: { onEnter(block) },
                onBackspaceEmpty: {},
                onSlash: { onSlash(block) }
            )
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func save() {
        block.updatedAt = Date()
        block.page?.updatedAt = Date()
        try? context.save()
    }
}
