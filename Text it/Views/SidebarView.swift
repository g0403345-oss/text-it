//
//  SidebarView.swift
//  Text it
//
//  Sidebar als ScrollView + LazyVStack, um List-Interferenz mit Drag & Drop zu vermeiden.
//

import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif

    @Query(sort: \Workspace.createdAt) private var workspaces: [Workspace]
    @Query(filter: #Predicate<Page> { !$0.isTrashed && $0.isFavorite && !$0.isPermanentlyDeleted })
    private var favorites: [Page]
    @Query(filter: #Predicate<Page> { $0.isTrashed && !$0.isPermanentlyDeleted })
    private var trashed: [Page]
    @Query(filter: #Predicate<Page> { !$0.isTrashed && !$0.isPermanentlyDeleted })
    private var allPages: [Page]

    @State private var trashExpanded: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                // MARK: Aktionen
                sidebarActionButton(title: "Schnellsuche", icon: "magnifyingglass") {
                    appState.showSearch = true
                }
                sidebarActionButton(title: "Neue Seite", icon: "plus.square.fill") {
                    createTopLevel()
                }

                sectionHeader("Navigation")

                // MARK: Navigation
                ForEach(navItems, id: \.section) { item in
                    NavSectionRow(title: item.title, icon: item.icon,
                                  color: item.color, section: item.section)
                        .sidebarRow()
                }

                // MARK: Favoriten
                if !favorites.isEmpty {
                    sectionHeader("Favoriten")
                    ForEach(favorites) { page in
                        PageRow(page: page, depth: 0, onMove: movePage)
                            .sidebarRow()
                    }
                }

                // MARK: Workspaces
                ForEach(workspaces) { ws in
                    workspaceSection(ws)
                }

                // MARK: Papierkorb
                sectionHeader("Papierkorb")
                DisclosureGroup(isExpanded: $trashExpanded) {
                    if trashed.isEmpty {
                        Text("Leer")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 32)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(trashed) { page in TrashRow(page: page).sidebarRow() }
                    }
                } label: {
                    Label("Papierkorb", systemImage: "trash.fill")
                        .font(.callout)
                        .foregroundStyle(trashed.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.red))
                        .sidebarRow()
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationTitle("Text it")
        #if os(iOS)
        .sheet(isPresented: Binding(get: { appState.showSettings }, set: { appState.showSettings = $0 })) {
            SettingsView().environment(appState)
        }
        #endif
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Action Button

    private func sidebarActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.callout)
                .foregroundStyle(appState.theme.accent)
                .sidebarRow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Workspace Section

    @ViewBuilder
    private func workspaceSection(_ ws: Workspace) -> some View {
        HStack {
            Image(systemName: ws.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(appState.theme.accent)
            Text(ws.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button { createFolder(in: ws) } label: {
                Image(systemName: "folder.badge.plus").font(.caption)
            }
            .buttonStyle(.plain).foregroundStyle(.secondary).help("Neuer Ordner")

            Button { createPage(in: ws) } label: {
                Image(systemName: "plus").font(.caption)
            }
            .buttonStyle(.plain).foregroundStyle(.secondary).help("Neue Seite")
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 2)
        // Drop-Zone für "aus Ordner rausziehen"
        .dropDestination(for: String.self) { items, _ in
            guard let idStr = items.first else { return false }
            movePage(idStr: idStr, toParent: nil, inWorkspace: ws)
            return true
        }

        let roots = (ws.pages ?? [])
            .filter { $0.parent == nil && !$0.isTrashed }
            .sorted { $0.sortIndex < $1.sortIndex }

        ForEach(roots) { page in
            PageRow(
                page: page,
                depth: 0,
                onMove: movePage,
                onReorderDrop: { idStr, target, before in
                    reorderByDrop(idStr: idStr, relativeTo: target,
                                  insertBefore: before, workspace: ws)
                }
            )
            .sidebarRow()
        }
    }

    // MARK: - Nav Items

    private var navItems: [(section: AppState.SidebarSection, title: String, icon: String, color: Color)] {
        [
            (.dashboard,  "Dashboard",      "house.fill",              .blue),
            (.todos,      "Tägliche Todos", "checklist",               Color(red: 0.18, green: 0.72, blue: 0.45)),
            (.tags,       "Tags",           "tag.fill",                .purple),
            (.templates,  "Vorlagen",       "rectangle.grid.2x2.fill", .orange),
            (.timeline,   "Zeitstrahl",     "calendar",                .teal),
            (.flashcards, "Lernkarten",     "rectangle.on.rectangle.angled", Color(red: 0.55, green: 0.25, blue: 0.9)),
        ]
    }

    // MARK: - Drop / Move

    private func movePage(idStr: String, toParent newParent: Page?, inWorkspace ws: Workspace?) {
        guard let id = UUID(uuidString: idStr),
              let page = allPages.first(where: { $0.id == id }) else { return }
        if let p = newParent {
            if p.id == page.id { return }
            if isDescendant(p, of: page) { return }
        }
        PageActions(context: context).movePage(page, toParent: newParent, inWorkspace: ws)
    }

    private func isDescendant(_ candidate: Page, of ancestor: Page) -> Bool {
        var cur = candidate.parent
        while let c = cur { if c.id == ancestor.id { return true }; cur = c.parent }
        return false
    }

    private func reorderByDrop(idStr: String, relativeTo target: Page,
                               insertBefore: Bool, workspace: Workspace) {
        guard let id = UUID(uuidString: idStr),
              let dragged = allPages.first(where: { $0.id == id }),
              dragged.id != target.id else { return }
        if isDescendant(target, of: dragged) { return }

        let targetParent = target.parent
        let targetWS = targetParent?.workspace ?? workspace
        dragged.parent = targetParent
        dragged.workspace = targetWS

        var siblings: [Page]
        if let parent = targetParent {
            siblings = (parent.children ?? [])
                .filter { !$0.isTrashed && $0.id != dragged.id }
                .sorted { $0.sortIndex < $1.sortIndex }
        } else {
            siblings = (targetWS.pages ?? [])
                .filter { $0.parent == nil && !$0.isTrashed && $0.id != dragged.id }
                .sorted { $0.sortIndex < $1.sortIndex }
        }

        if let idx = siblings.firstIndex(where: { $0.id == target.id }) {
            siblings.insert(dragged, at: insertBefore ? idx : idx + 1)
        } else {
            siblings.append(dragged)
        }
        for (i, p) in siblings.enumerated() { p.sortIndex = i }
        try? context.save()
    }

    // MARK: - Creation

    private func createTopLevel() {
        guard let ws = workspaces.first else { return }
        let page = PageActions(context: context).createPage(in: ws)
        appState.navigateTo(pageID: page.id)
    }

    private func createPage(in ws: Workspace) {
        let page = PageActions(context: context).createPage(in: ws)
        appState.navigateTo(pageID: page.id)
    }

    private func createFolder(in ws: Workspace) {
        let folder = PageActions(context: context).createFolder(in: ws)
        appState.navigateTo(pageID: folder.id)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                SyncStatusView()
                    .frame(maxWidth: .infinity, alignment: .leading)
                #if os(macOS)
                Button { openSettings() } label: {
                    Image(systemName: "gearshape.fill").font(.callout).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).help("Einstellungen")
                #else
                Button { appState.showSettings = true } label: {
                    Image(systemName: "gearshape.fill").font(.callout).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                #endif
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.thinMaterial)
    }
}

// MARK: - SidebarRow modifier

extension View {
    func sidebarRow() -> some View {
        self
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
}

// MARK: - NavSectionRow

struct NavSectionRow: View {
    let title: String
    let icon: String
    let color: Color
    let section: AppState.SidebarSection

    @Environment(AppState.self) private var appState

    private var isActive: Bool {
        appState.selectedPageID == nil && appState.activeSidebarSection == section
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                appState.openSection(section)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isActive ? .white : color)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(isActive ? color : color.opacity(0.14))
                    )
                Text(title)
                    .font(.system(.callout, design: .default, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(.primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            isActive
                ? RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12))
                : nil
        )
    }
}

// MARK: - PageRow (rekursiv, Drag & Drop)

struct PageRow: View {
    @Bindable var page: Page
    let depth: Int
    var onMove: (String, Page?, Workspace?) -> Void
    var onReorderDrop: ((String, Page, Bool) -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var isEditing: Bool = false
    @State private var draftTitle: String = ""
    @State private var isDropTarget: Bool = false
    @FocusState private var renameFocused: Bool

    private var isSelected: Bool { appState.selectedPageID == page.id }

    var body: some View {
        let children = page.sortedChildren

        Group {
            if children.isEmpty {
                rowContent
                    .draggable(page.id.uuidString)
            } else {
                DisclosureGroup(isExpanded: Binding(
                    get: { page.isExpanded },
                    set: { page.isExpanded = $0; try? context.save() }
                )) {
                    ForEach(children) { child in
                        PageRow(
                            page: child,
                            depth: depth + 1,
                            onMove: onMove,
                            onReorderDrop: { idStr, target, before in
                                // Kinder können auch neu geordnet werden
                                guard let id = UUID(uuidString: idStr),
                                      let dragged = (page.children ?? []).first(where: { $0.id == id }),
                                      dragged.id != target.id else { return }
                                var siblings = (page.children ?? [])
                                    .filter { !$0.isTrashed && $0.id != dragged.id }
                                    .sorted { $0.sortIndex < $1.sortIndex }
                                if let idx = siblings.firstIndex(where: { $0.id == target.id }) {
                                    siblings.insert(dragged, at: before ? idx : idx + 1)
                                } else {
                                    siblings.append(dragged)
                                }
                                for (i, p) in siblings.enumerated() { p.sortIndex = i }
                                try? context.save()
                            }
                        )
                        .padding(.leading, 16)
                    }
                } label: {
                    rowContent
                        .draggable(page.id.uuidString)
                }
            }
        }
        .tag(page.id)
        .dropDestination(for: String.self) { items, location in
            isDropTarget = false
            guard let idStr = items.first, idStr != page.id.uuidString else { return false }
            if page.isFolder {
                onMove(idStr, page, nil)
                return true
            } else if let reorder = onReorderDrop {
                reorder(idStr, page, location.y < 22)
                return true
            }
            return false
        } isTargeted: { targeted in
            isDropTarget = targeted && (page.isFolder || onReorderDrop != nil)
        }
        .background(
            Group {
                if isDropTarget {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(page.isFolder
                              ? Color.accentColor.opacity(0.18)
                              : Color.accentColor.opacity(0.08))
                } else if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(appState.theme.accent.opacity(0.14))
                }
            }
        )
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            Image(systemName: page.isFolder ? "folder.fill" : page.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(page.isFolder ? AnyShapeStyle(Color.yellow) : AnyShapeStyle(.tint))
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(page.isFolder
                              ? Color.yellow.opacity(0.14)
                              : Color.accentColor.opacity(0.10))
                )

            if isEditing {
                TextField("Titel", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .focused($renameFocused)
                    .onSubmit { commitRename() }
                    .onChange(of: renameFocused) { _, focused in
                        if !focused && isEditing { commitRename() }
                    }
            } else {
                Text(page.title.isEmpty ? "Unbenannt" : page.title)
                    .font(.callout)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? appState.theme.accent : .primary)
            }

            Spacer(minLength: 0)

            if page.isFavorite {
                Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture { if !isEditing { appState.selectedPageID = page.id } }
        .contextMenu { contextMenuItems }
        .onChange(of: isEditing) { _, editing in
            if editing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { renameFocused = true }
            }
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Umbenennen") { draftTitle = page.title; isEditing = true }
        if !page.isFolder {
            Button("Neue Unterseite") {
                let new = PageActions(context: context).createPage(in: page.workspace, parent: page)
                appState.navigateTo(pageID: new.id)
            }
            Button("Neuer Unterordner") {
                let folder = PageActions(context: context).createFolder(in: page.workspace, parent: page)
                appState.navigateTo(pageID: folder.id)
            }
        } else {
            Button("Neue Seite im Ordner") {
                let new = PageActions(context: context).createPage(in: page.workspace, parent: page)
                appState.navigateTo(pageID: new.id)
            }
            Button("Neuer Unterordner") {
                let folder = PageActions(context: context).createFolder(in: page.workspace, parent: page)
                appState.navigateTo(pageID: folder.id)
            }
        }
        Button(page.isFavorite ? "Aus Favoriten entfernen" : "Zu Favoriten") {
            PageActions(context: context).toggleFavorite(page)
        }
        if !page.isFolder {
            Button("Duplizieren") { PageActions(context: context).duplicate(page) }
        }
        Divider()
        Button("In Papierkorb", role: .destructive) {
            PageActions(context: context).moveToTrash(page)
            if appState.selectedPageID == page.id { appState.selectedPageID = nil }
        }
    }

    private func commitRename() {
        PageActions(context: context).rename(page, to: draftTitle.isEmpty ? "Unbenannt" : draftTitle)
        isEditing = false
    }
}

// MARK: - TrashRow

struct TrashRow: View {
    @Bindable var page: Page
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: page.isFolder ? "folder.fill" : page.icon)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.10)))

            Text(page.title.isEmpty ? "Unbenannt" : page.title)
                .font(.callout)
                .lineLimit(1)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                withAnimation { PageActions(context: context).restore(page) }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Wiederherstellen")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture { appState.navigateTo(pageID: page.id) }
        .contextMenu {
            Button("Vorschau") { appState.navigateTo(pageID: page.id) }
            Button("Wiederherstellen") { PageActions(context: context).restore(page) }
            Divider()
            Button("Endgültig löschen", role: .destructive) {
                PageActions(context: context).deletePermanently(page)
            }
        }
    }
}
