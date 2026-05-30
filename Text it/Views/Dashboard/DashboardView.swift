//
//  DashboardView.swift
//  Text it
//
//  Startseite mit Statistiken, Schnellzugriff und zuletzt bearbeiteten Seiten.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Page> { !$0.isTrashed })
    private var allPages: [Page]

    @Query(sort: \DailyTodo.sortIndex)
    private var allTodos: [DailyTodo]

    private var todaysTodos: [DailyTodo] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        return allTodos.filter { $0.targetDate >= today && $0.targetDate < tomorrow }
    }

    @Query(filter: #Predicate<Page> { !$0.isTrashed && $0.isFavorite })
    private var favorites: [Page]

    @Query(filter: #Predicate<Page> { !$0.isTrashed && !$0.isFolder },
           sort: \Page.updatedAt, order: .reverse)
    private var recentPages: [Page]

    @Query private var workspaces: [Workspace]

    private var totalWords: Int {
        allPages.reduce(0) { $0 + $1.wordCount }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "Guten Morgen"
        case 12..<17: return "Guten Nachmittag"
        case 17..<22: return "Guten Abend"
        default:      return "Gute Nacht"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                heroHeader
                statsRow
                quickActions
                todosWidget
            if !recentPages.isEmpty { recentSection }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .navigationTitle("Dashboard")
    }

    // MARK: - Hero

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(appState.theme.heroGradient)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(appState.theme.accent.opacity(0.25), lineWidth: 1)
                )

            // Dekoratives Hintergrundmuster
            Circle()
                .fill(appState.theme.accent.opacity(0.08))
                .frame(width: 160, height: 160)
                .offset(x: -30, y: 50)

            Circle()
                .fill(appState.theme.accent.opacity(0.06))
                .frame(width: 100, height: 100)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(x: -20, y: -20)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: appState.theme.systemIcon)
                        .font(.title2)
                        .foregroundStyle(appState.theme.accent)
                    Text(workspaces.first?.name ?? "Text it")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(greeting)
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(
                value: "\(allPages.filter { !$0.isFolder }.count)",
                label: "Seiten",
                icon: "doc.text.fill",
                color: appState.theme.accent
            )
            StatCard(
                value: totalWords > 999 ? "\(totalWords / 1000)k+" : "\(totalWords)",
                label: "Wörter",
                icon: "text.word.spacing",
                color: appState.theme.accent
            )
            StatCard(
                value: "\(favorites.count)",
                label: "Favoriten",
                icon: "star.fill",
                color: .yellow
            )
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Schnellzugriff", icon: "bolt.fill")
            HStack(spacing: 12) {
                DashboardActionButton(
                    title: "Neue Seite",
                    icon: "plus.square.fill",
                    color: appState.theme.accent
                ) { createNewPage() }

                DashboardActionButton(
                    title: "Suchen",
                    icon: "magnifyingglass",
                    color: .secondary
                ) { appState.showSearch = true }

                DashboardActionButton(
                    title: "Vorlagen",
                    icon: "rectangle.grid.2x2.fill",
                    color: .orange
                ) { appState.openSection(.templates) }

                DashboardActionButton(
                    title: "Zeitstrahl",
                    icon: "calendar",
                    color: .teal
                ) { appState.openSection(.timeline) }
            }
        }
    }

    // MARK: - Todos Widget

    private var todosWidget: some View {
        let total = todaysTodos.count
        let checked = todaysTodos.filter { $0.isChecked }.count
        let unchecked = todaysTodos.filter { !$0.isChecked }
        let progress = total == 0 ? 0.0 : Double(checked) / Double(total)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Heutige Aufgaben", icon: "checklist")
                Spacer()
                Button {
                    appState.openSection(.todos)
                } label: {
                    Text("Alle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(appState.theme.accent)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 14) {
                // Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            progress >= 1.0 ? Color.green : appState.theme.accent,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.4), value: progress)
                    VStack(spacing: 1) {
                        Text("\(checked)")
                            .font(.system(.callout, design: .rounded, weight: .bold))
                        Text("/\(total)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 56, height: 56)

                if unchecked.isEmpty && total > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Alles erledigt!")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.green)
                        Text("Großartige Arbeit heute.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if total == 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keine Aufgaben")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Button {
                            appState.openSection(.todos)
                        } label: {
                            Text("Aufgabe hinzufügen")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(appState.theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(unchecked.prefix(3)) { todo in
                            HStack(spacing: 8) {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                                    .frame(width: 14, height: 14)
                                Text(todo.text)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                                if todo.carriedOver {
                                    Image(systemName: "arrow.trianglehead.counterclockwise")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        if unchecked.count > 3 {
                            Text("+ \(unchecked.count - 3) weitere")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.quaternary.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(appState.theme.accent.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .onTapGesture { appState.openSection(.todos) }
    }

    // MARK: - Recent Pages

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Zuletzt bearbeitet", icon: "clock.fill")
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(Array(recentPages.prefix(6))) { page in
                    DashboardPageCard(page: page)
                        .onTapGesture { appState.navigateTo(pageID: page.id) }
                }
            }
        }
    }

    // MARK: - Actions

    private func createNewPage() {
        guard let ws = workspaces.first else { return }
        let page = PageActions(context: context).createPage(in: ws)
        appState.navigateTo(pageID: page.id)
    }
}

// MARK: - StatCard

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.quaternary.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// MARK: - DashboardActionButton

struct DashboardActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(color.opacity(0.12))
                    )
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DashboardPageCard

struct DashboardPageCard: View {
    let page: Page

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: page.icon)
                    .font(.title3)
                    .foregroundStyle(.tint)
                Spacer()
                Text(page.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.quaternary.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
        )
    }
}

// MARK: - SectionHeader

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
            Text(title)
                .font(.headline.weight(.semibold))
        }
    }
}
