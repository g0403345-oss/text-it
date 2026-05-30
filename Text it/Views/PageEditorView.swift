//
//  PageEditorView.swift
//  Text it
//

import SwiftUI
import SwiftData
import PencilKit

// Misst die natürliche Größe des Inhalts (für macOS-Overlay-Sizing)
private struct ContentSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let n = nextValue()
        value = CGSize(width: max(value.width, n.width),
                       height: max(value.height, n.height))
    }
}

struct PageEditorView: View {
    @Bindable var page: Page
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var showSlashMenu: Bool = false
    @State private var slashTargetBlock: Block? = nil
    @State private var contentSize: CGSize = .zero
    @State private var newTagText: String = ""
    @State private var isAddingTag: Bool = false
    @FocusState private var tagFieldFocused: Bool

    // Zoom-Scale: wird vom ZoomableScrollView (iOS) oder Toolbar-Button (macOS) gesetzt
    @State private var zoomScale: CGFloat = 1.0

    #if os(iOS) || os(visionOS)
    @State private var pencilTool = PencilToolState.shared
    #endif

    var body: some View {
        scrollView
            .onPreferenceChange(ContentSizeKey.self) { contentSize = $0 }
            .onChange(of: page.id) { _, _ in
                zoomScale = 1.0
                contentSize = .zero
            }
            .toolbar { toolbar }
            .sheet(isPresented: $showSlashMenu) {
                SlashMenuView { type in
                    if let target = slashTargetBlock {
                        PageActions(context: context).changeBlockType(target, to: type)
                    } else {
                        _ = PageActions(context: context).addBlock(to: page, type: type)
                    }
                    showSlashMenu = false
                }
                .frame(minWidth: 320, idealWidth: 420, maxWidth: 480,
                       minHeight: 380, idealHeight: 500, maxHeight: 620)
            }
            .overlay(alignment: .bottom) {
                #if os(iOS) || os(visionOS)
                if appState.pencilHandwritingMode {
                    PencilToolbar()
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                #endif
            }
            .animation(.snappy, value: appState.pencilHandwritingMode)
    }

    // MARK: - Scroll-Container (plattformabhängig)

    @ViewBuilder
    private var scrollView: some View {
        #if os(iOS)
        ZoomableScrollView(
            zoomScale: $zoomScale,
            pageID: page.id,
            onPencilDoubleTap: {
                // Doppeltippen: Radierer ↔ letztes Werkzeug
                let ts = PencilToolState.shared
                if ts.tool == .eraser {
                    ts.tool = ts.lastNonEraserTool
                } else {
                    ts.tool = .eraser
                }
            },
            onPencilDetected: {
                if appState.pencilAutoDetect {
                    appState.pencilHandwritingMode = true
                }
            },
            onFingerDetected: {
                if appState.pencilAutoDetect && appState.pencilHandwritingMode {
                    appState.pencilHandwritingMode = false
                }
            }
        ) {
            editorContent
        }
        .id(page.id)
        #else
        ScrollView([.vertical, .horizontal]) {
            editorContent
        }
        // Scroll-Position auf macOS beim Seitenwechsel zurücksetzen.
        .id(page.id)
        #endif
    }

    // MARK: - Eigentlicher Seiteninhalt

    @ViewBuilder
    private var editorContent: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                breadcrumb
                header
                Divider().padding(.vertical, 4)

                ForEach(page.sortedTopLevelBlocks) { block in
                    BlockRowView(
                        block: block,
                        onEnter: { current in
                            _ = PageActions(context: context).addBlock(to: page, type: .text, after: current)
                        },
                        onDelete: { b in
                            PageActions(context: context).deleteBlock(b)
                        },
                        onSlash: { b in
                            slashTargetBlock = b
                            showSlashMenu = true
                        },
                        onChangeType: { b, type in
                            PageActions(context: context).changeBlockType(b, to: type)
                        }
                    )
                    .padding(.vertical, 2)
                }

                Button {
                    _ = PageActions(context: context).addBlock(to: page, type: .text)
                } label: {
                    Label("Block hinzufügen", systemImage: "plus")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .frame(minWidth: 900, maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                // Nur auf macOS benötigt (für overlay-Sizing); auf iOS übernimmt UIScrollView
                GeometryReader { geo in
                    Color.clear.preference(key: ContentSizeKey.self, value: geo.size)
                }
            )

            // Apple-Pencil-Handschrift-Overlay
            handwritingOverlay
        }
        .frame(maxWidth: .infinity, alignment: .top)
        // Auf macOS: manueller Zoom via scaleEffect (keine Pinch-Geste auf Mac)
        #if os(macOS)
        .scaleEffect(zoomScale, anchor: .top)
        .frame(minHeight: contentSize.height * max(zoomScale, 1.0))
        #endif
    }

    // MARK: - Handschrift-Overlay

    @ViewBuilder
    private var handwritingOverlay: some View {
        #if os(iOS) || os(visionOS)
        if appState.pencilHandwritingMode {
            PageHandwritingCanvas(
                data: Binding(
                    get: { page.drawingData },
                    set: { newValue in
                        page.drawingData = newValue
                        page.updatedAt = Date()
                        try? context.save()
                    }
                ),
                tool: pencilTool.makePKTool(),
                toolVersion: pencilTool.version
            )
            .frame(minWidth: 900, maxWidth: 900)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(maxHeight: .infinity)
        } else if let data = page.drawingData, !data.isEmpty {
            PageDrawingImage(data: data)
                .frame(minWidth: 900, maxWidth: 900)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(maxHeight: .infinity)
        }
        #else
        if let data = page.drawingData, !data.isEmpty {
            PageDrawingImage(data: data)
                .frame(minWidth: 900, maxWidth: 900)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(maxHeight: .infinity)
        }
        #endif
    }

    // MARK: - Breadcrumb

    private var breadcrumb: some View {
        HStack(spacing: 4) {
            ForEach(ancestors(of: page), id: \.id) { ancestor in
                Button {
                    appState.navigateTo(pageID: ancestor.id)
                } label: {
                    Text(ancestor.title.isEmpty ? "Unbenannt" : ancestor.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(page.title.isEmpty ? "Unbenannt" : page.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if page.wordCount > 0 {
                Text("\(page.wordCount) W")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                IconPicker(icon: Binding(
                    get: { page.icon },
                    set: { page.icon = $0; try? context.save() }
                ))

                BlockTextField(
                    text: Binding(
                        get: { page.title },
                        set: { page.title = $0; page.updatedAt = Date(); try? context.save() }
                    ),
                    placeholder: "Titel der Seite",
                    font: .system(size: 34, weight: .bold),
                    uiFontSize: 34,
                    uiFontWeight: .bold
                )
            }

            // Tags
            tagEditor
        }
    }

    // MARK: - Tag Editor

    private var tagEditor: some View {
        FlexRow {
            ForEach(page.tags, id: \.self) { tag in
                HStack(spacing: 4) {
                    Text(tag)
                        .font(.caption.weight(.medium))
                    Button {
                        var tags = page.tags
                        tags.removeAll { $0 == tag }
                        page.tags = tags
                        try? context.save()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(appState.theme.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(appState.theme.accent.opacity(0.13))
                )
            }

            if isAddingTag {
                TextField("Tag…", text: $newTagText)
                    .textFieldStyle(.plain)
                    .font(.caption.weight(.medium))
                    .focused($tagFieldFocused)
                    .frame(minWidth: 60, maxWidth: 140)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().stroke(appState.theme.accent.opacity(0.5), lineWidth: 1))
                    .onSubmit { commitTag() }
                    .onChange(of: tagFieldFocused) { _, focused in
                        if !focused { commitTag() }
                    }
            } else {
                Button {
                    isAddingTag = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { tagFieldFocused = true }
                } label: {
                    Label("Tag", systemImage: "plus")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func commitTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !page.tags.contains(trimmed) {
            var tags = page.tags
            tags.append(trimmed)
            page.tags = tags
            try? context.save()
        }
        newTagText = ""
        isAddingTag = false
        tagFieldFocused = false
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if appState.canGoBack {
            ToolbarItem(placement: .navigation) {
                Button { appState.navigateBack() } label: {
                    Image(systemName: "chevron.left")
                }
                .help("Zurück")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            SyncStatusView()
        }

        ToolbarItem(placement: .primaryAction) {
            PomodoroToolbarButton()
                .popover(isPresented: Binding(
                    get: { appState.showPomodoro },
                    set: { appState.showPomodoro = $0 }
                )) {
                    PomodoroView()
                        .environment(appState)
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
                }
        }

        #if os(iOS) || os(visionOS)
        ToolbarItem(placement: .primaryAction) {
            Button {
                appState.pencilHandwritingMode.toggle()
            } label: {
                Image(systemName: appState.pencilHandwritingMode
                      ? "applepencil.tip"
                      : "hand.draw.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(appState.pencilHandwritingMode
                                     ? appState.theme.accent
                                     : Color.secondary)
            }
            .help(appState.pencilHandwritingMode ? "Schreiben (Pencil aktiv)" : "Tippen (Finger-Modus)")
        }
        #endif

        // Zoom-Reset (nur wenn Zoom aktiv)
        if abs(zoomScale - 1.0) > 0.05 {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.spring) { zoomScale = 1.0 }
                } label: {
                    Image(systemName: "1.magnifyingglass")
                }
                .help("Zoom zurücksetzen")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                PageActions(context: context).toggleFavorite(page)
            } label: {
                Image(systemName: page.isFavorite ? "star.fill" : "star")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Neue Unterseite") {
                    let child = PageActions(context: context).createPage(in: page.workspace, parent: page)
                    appState.navigateTo(pageID: child.id)
                }
                Button("Duplizieren") {
                    PageActions(context: context).duplicate(page)
                }
                Divider()
                Button("Als Markdown kopieren") {
                    let md = PageActions(context: context).exportMarkdown(page: page)
                    #if os(iOS)
                    UIPasteboard.general.string = md
                    #else
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(md, forType: .string)
                    #endif
                }
                Divider()
                Button("In Papierkorb", role: .destructive) {
                    PageActions(context: context).moveToTrash(page)
                    appState.selectedPageID = nil
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Helpers

    private func ancestors(of page: Page) -> [Page] {
        var result: [Page] = []
        var current = page.parent
        while let c = current {
            result.insert(c, at: 0)
            current = c.parent
        }
        return result
    }
}

// MARK: - FlexRow (Tag-Zeile mit automatischem Umbruch, nutzt FlowLayout aus TagsView)

struct FlexRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        FlowLayout(spacing: 6) { content }
    }
}

// MARK: - Icon Picker

struct IconPicker: View {
    @Binding var icon: String
    private let icons = [
        "doc.text", "sparkles", "book", "graduationcap", "lightbulb",
        "list.bullet", "calendar", "checklist", "tray.full", "folder",
        "tag", "star", "heart", "flame", "leaf", "globe", "cube",
        "paintbrush", "music.note", "camera", "bolt", "scribble",
        "brain", "hammer", "airplane", "cart", "person.crop.circle"
    ]

    var body: some View {
        Menu {
            ForEach(icons, id: \.self) { name in
                Button { icon = name } label: {
                    Label(name, systemImage: name)
                }
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 28))
                .frame(width: 40, height: 40)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
    }
}
