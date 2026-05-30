//
//  FolderView.swift
//  Text it
//
//  Detailansicht für Ordner-Seiten: zeigt Kinder als Karten-Grid.
//

import SwiftUI
import SwiftData

struct FolderView: View {
    @Bindable var page: Page
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.yellow)
                    TextField("Ordnername", text: Binding(
                        get: { page.title },
                        set: { page.title = $0; page.updatedAt = Date(); try? context.save() }
                    ))
                    .font(.system(size: 34, weight: .bold))
                    #if os(macOS)
                    .textFieldStyle(.plain)
                    #else
                    .textFieldStyle(.plain)
                    #endif
                }
                .padding(.horizontal, 32)

                Divider().padding(.horizontal, 32)

                // Kinder-Grid
                let children = page.sortedChildren
                if children.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("Dieser Ordner ist leer")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(children) { child in
                            PageCard(page: child)
                        }
                    }
                    .padding(.horizontal, 32)
                }

                // Neue Seite / Ordner erstellen
                HStack(spacing: 12) {
                    Button {
                        let p = PageActions(context: context).createPage(in: page.workspace, parent: page)
                        appState.navigateTo(pageID: p.id)
                    } label: {
                        Label("Neue Seite", systemImage: "plus.square")
                            .font(.callout)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        let f = PageActions(context: context).createFolder(in: page.workspace, parent: page)
                        appState.navigateTo(pageID: f.id)
                    } label: {
                        Label("Neuer Unterordner", systemImage: "folder.badge.plus")
                            .font(.callout)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .padding(.vertical, 24)
        }
        .navigationTitle(page.title.isEmpty ? "Ordner" : page.title)
        .toolbar {
            if appState.canGoBack {
                ToolbarItem(placement: .navigation) {
                    Button { appState.navigateBack() } label: {
                        Image(systemName: "chevron.left")
                    }
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
                    Button("Neue Seite im Ordner") {
                        let p = PageActions(context: context).createPage(in: page.workspace, parent: page)
                        appState.navigateTo(pageID: p.id)
                    }
                    Button("Neuer Unterordner") {
                        let f = PageActions(context: context).createFolder(in: page.workspace, parent: page)
                        appState.navigateTo(pageID: f.id)
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
    }
}

// MARK: - Seiten-Karte im Ordner

struct PageCard: View {
    let page: Page
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    var body: some View {
        Button { appState.navigateTo(pageID: page.id) } label: {
            RoundedRectangle(cornerRadius: 14)
                .fill(.quaternary.opacity(0.6))
                .frame(height: 110)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: page.isFolder ? "folder.fill" : page.icon)
                            .font(.title2)
                            .foregroundStyle(page.isFolder ? Color.yellow : Color.accentColor)
                        Text(page.title.isEmpty ? "Unbenannt" : page.title)
                            .font(.callout.weight(.medium))
                            .lineLimit(2)
                            .foregroundStyle(.primary)
                    }
                    .padding(14)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        // Seite aus Ordner heraus ziehbar machen
        .draggable(page.id.uuidString)
        // Ordner-Karten als Drop-Ziel: gezogene Seite wird Kind dieses Ordners
        .dropDestination(for: String.self) { items, _ in
            guard page.isFolder, let idStr = items.first,
                  let id = UUID(uuidString: idStr) else { return false }
            // Selbst-Drop und Kreis-Drop verhindern
            if id == page.id { return false }
            // Über modelContext direkt suchen
            let descriptor = FetchDescriptor<Page>()
            guard let all = try? context.fetch(descriptor),
                  let dragged = all.first(where: { $0.id == id }) else { return false }
            var cur = page.parent
            while let c = cur { if c.id == id { return false }; cur = c.parent }
            PageActions(context: context).movePage(dragged, toParent: page, inWorkspace: nil)
            return true
        }
    }
}
