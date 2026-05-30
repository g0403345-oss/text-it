//
//  RootView.swift
//  Text it
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query private var workspaces: [Workspace]
    @Query(filter: #Predicate<Page> { !$0.isTrashed })
    private var allPages: [Page]
    /// Alle Seiten inkl. Papierkorb — für Navigation zu gelöschten Seiten (Vorschau).
    @Query private var allPagesForNavigation: [Page]

    var body: some View {
        @Bindable var state = appState

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 360)
        } detail: {
            detailContent
        }
        .sheet(isPresented: $state.showSearch) {
            SearchView()
                .environment(appState)
                .frame(minWidth: 520, minHeight: 420)
        }
        .onAppear { ensureWorkspace() }
        .onAppear { DeviceHeartbeat.shared.start(context: context) }
        .onAppear { carryOverTodos() }
        .onReceive(NotificationCenter.default.publisher(for: .createNewPage)) { _ in
            createNewTopLevelPage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSearch)) { _ in
            appState.showSearch = true
        }
        // Onboarding beim ersten Start
        #if os(iOS)
        .fullScreenCover(isPresented: Binding(
            get: { !appState.hasCompletedOnboarding },
            set: { _ in }
        )) {
            OnboardingView()
                .environment(appState)
        }
        #else
        .sheet(isPresented: Binding(
            get: { !appState.hasCompletedOnboarding },
            set: { _ in }
        )) {
            OnboardingView()
                .environment(appState)
                .frame(minWidth: 560, minHeight: 660)
        }
        #endif
    }

    // MARK: - Detail Routing

    @ViewBuilder
    private var detailContent: some View {
        if let id = appState.selectedPageID,
           let page = allPagesForNavigation.first(where: { $0.id == id }) {
            if page.isTrashed {
                // Papierkorb-Vorschau: Banner + Read-only Editor
                VStack(spacing: 0) {
                    trashedBanner(page: page)
                    Divider()
                    if page.isFolder {
                        FolderView(page: page)
                    } else {
                        PageEditorView(page: page)
                    }
                }
            } else if page.isFolder {
                FolderView(page: page)
            } else {
                PageEditorView(page: page)
            }
        } else {
            // Section-View basierend auf aktivem Sidebar-Abschnitt
            switch appState.activeSidebarSection {
            case .dashboard:
                DashboardView()
            case .tags:
                TagsView()
            case .templates:
                TemplateGalleryView()
            case .timeline:
                TimelineView()
            case .flashcards:
                FlashcardsView()
            case .todos:
                DailyTodosView()
            case .favorites:
                FavoritesView()
            case .trash:
                TrashDetailView()
            case .pages:
                AllPagesView()
            }
        }
    }

    // MARK: - Trashed Banner

    private func trashedBanner(page: Page) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "trash.fill")
                .foregroundStyle(.orange)
            Text("Diese Seite liegt im Papierkorb")
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer()
            Button {
                PageActions(context: context).restore(page)
            } label: {
                Text("Wiederherstellen")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            Button {
                PageActions(context: context).deletePermanently(page)
                appState.selectedPageID = nil
            } label: {
                Text("Endgültig löschen")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.10))
    }

    // MARK: - Helpers

    private func ensureWorkspace() {
        if workspaces.isEmpty {
            let ws = Workspace()
            context.insert(ws)
            try? context.save()
        }
    }

    private func createNewTopLevelPage() {
        guard let ws = workspaces.first else { return }
        let page = PageActions(context: context).createPage(in: ws)
        appState.navigateTo(pageID: page.id)
    }

    private func carryOverTodos() {
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<DailyTodo>(
            predicate: #Predicate { !$0.isChecked }
        )
        guard let unchecked = try? context.fetch(descriptor) else { return }
        let overdue = unchecked.filter { $0.targetDate < today }
        guard !overdue.isEmpty else { return }
        for todo in overdue {
            todo.targetDate = today
            todo.carriedOver = true
        }
        try? context.save()
    }
}

// MARK: - AllPagesView

struct AllPagesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Page> { !$0.isTrashed && !$0.isFolder },
           sort: \Page.updatedAt, order: .reverse)
    private var pages: [Page]

    @Query private var workspaces: [Workspace]
    @State private var searchText: String = ""

    private var filtered: [Page] {
        guard !searchText.isEmpty else { return pages }
        return pages.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Alle Seiten")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("\(pages.count) Seiten")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        guard let ws = workspaces.first else { return }
                        let page = PageActions(context: context).createPage(in: ws)
                        appState.navigateTo(pageID: page.id)
                    } label: {
                        Label("Neue Seite", systemImage: "plus")
                            .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(appState.theme.accent)
                }

                // Suche
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Seiten suchen…", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.5)))

                // Seiten-Grid
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(filtered) { page in
                        AllPagesCard(page: page) {
                            appState.navigateTo(pageID: page.id)
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .navigationTitle("Alle Seiten")
    }
}

struct AllPagesCard: View {
    let page: Page
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: page.icon)
                        .font(.title3)
                        .foregroundStyle(.tint)
                    Spacer()
                    Text(page.updatedAt.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                Text(page.title.isEmpty ? "Unbenannt" : page.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                if page.wordCount > 0 {
                    Text("\(page.wordCount) Wörter")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if page.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.quaternary.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.quaternary, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FavoritesView

struct FavoritesView: View {
    @Environment(AppState.self) private var appState

    @Query(filter: #Predicate<Page> { !$0.isTrashed && $0.isFavorite },
           sort: \Page.updatedAt, order: .reverse)
    private var favorites: [Page]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Favoriten")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("\(favorites.count) markierte Seiten")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if favorites.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 52))
                            .foregroundStyle(.tertiary)
                        Text("Noch keine Favoriten")
                            .font(.title3.weight(.semibold))
                        Text("Markiere Seiten als Favorit über das Kontextmenü oder den Stern in der Toolbar.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 14)],
                        spacing: 14
                    ) {
                        ForEach(favorites) { page in
                            AllPagesCard(page: page) {
                                appState.navigateTo(pageID: page.id)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .navigationTitle("Favoriten")
    }
}

// MARK: - TrashDetailView

struct TrashDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @Query(filter: #Predicate<Page> { $0.isTrashed })
    private var trashed: [Page]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Papierkorb")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("\(trashed.count) Seite\(trashed.count == 1 ? "" : "n")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !trashed.isEmpty {
                        Button("Alle löschen", role: .destructive) {
                            trashed.forEach { PageActions(context: context).deletePermanently($0) }
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }

                if trashed.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "trash.slash")
                            .font(.system(size: 52))
                            .foregroundStyle(.tertiary)
                        Text("Papierkorb ist leer")
                            .font(.title3.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    ForEach(trashed) { page in
                        TrashDetailRow(page: page)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .navigationTitle("Papierkorb")
    }
}

struct TrashDetailRow: View {
    let page: Page
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: page.icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(page.title.isEmpty ? "Unbenannt" : page.title)
                    .font(.callout.weight(.medium))
                Text(page.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Wiederherstellen") {
                PageActions(context: context).restore(page)
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(.blue)

            Button(role: .destructive) {
                PageActions(context: context).deletePermanently(page)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary.opacity(0.4))
        )
    }
}

// MARK: - Legacy

struct WelcomePlaceholder: View {
    var body: some View {
        DashboardView()
    }
}
