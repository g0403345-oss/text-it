//
//  TimelineView.swift
//  Text it
//
//  Zeitstrahl: Seiten nach Monat gruppiert, chronologisch sortiert.
//

import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(AppState.self) private var appState

    @Query(filter: #Predicate<Page> { !$0.isTrashed && !$0.isFolder },
           sort: \Page.updatedAt, order: .reverse)
    private var pages: [Page]

    private var groupedByMonth: [(month: String, pages: [Page])] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "MMMM yyyy"

        var dict: [String: [Page]] = [:]
        var order: [String] = []

        for page in pages {
            let key = formatter.string(from: page.updatedAt)
            if dict[key] == nil {
                order.append(key)
                dict[key] = []
            }
            dict[key]?.append(page)
        }

        return order.map { key in
            (month: key, pages: dict[key] ?? [])
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Zeitstrahl")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("\(pages.count) Seiten")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)

                if pages.isEmpty {
                    emptyState
                } else {
                    timelineContent
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Zeitstrahl")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text("Noch keine Seiten")
                .font(.title3.weight(.semibold))
            Text("Erstelle deine erste Seite, um sie hier im Zeitstrahl zu sehen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 24)
    }

    // MARK: - Timeline Content

    private var timelineContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(groupedByMonth, id: \.month) { group in
                MonthSection(month: group.month, pages: group.pages) { pageID in
                    appState.navigateTo(pageID: pageID)
                }
            }
        }
    }
}

// MARK: - MonthSection

struct MonthSection: View {
    let month: String
    let pages: [Page]
    let onTap: (UUID) -> Void

    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Monats-Header
            Button {
                withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    // Timeline-Linie
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 12, height: 12)
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.3))
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(width: 24)

                    HStack {
                        Text(month)
                            .font(.headline.weight(.bold))
                        Text("·  \(pages.count) Seite\(pages.count == 1 ? "" : "n")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Seiten dieses Monats
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { idx, page in
                        HStack(alignment: .top, spacing: 12) {
                            // Timeline-Linie
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.accentColor.opacity(0.3))
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                                if idx == pages.count - 1 {
                                    Color.clear.frame(width: 2, height: 12)
                                }
                            }
                            .frame(width: 24, alignment: .center)
                            .overlay(
                                Circle()
                                    .fill(Color.accentColor.opacity(0.4))
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 14),
                                alignment: .top
                            )

                            TimelinePageRow(page: page) {
                                onTap(page.id)
                            }
                        }
                        .padding(.leading, 24)
                        .padding(.trailing, 20)
                        .padding(.vertical, 2)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }

            // Abstandshalter zwischen Monaten
            Color.clear.frame(height: 8)
        }
    }
}

// MARK: - TimelinePageRow

struct TimelinePageRow: View {
    let page: Page
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    // Datum
                    Text(page.updatedAt.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tint)
                        .monospacedDigit()

                    // Titel
                    Text(page.title.isEmpty ? "Unbenannt" : page.title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Meta
                    HStack(spacing: 8) {
                        if page.wordCount > 0 {
                            Label("\(page.wordCount) Wörter", systemImage: "text.word.spacing")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        if page.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                Spacer()

                Image(systemName: page.icon)
                    .font(.title3)
                    .foregroundStyle(.tint.opacity(0.6))

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.bottom, 6)
    }
}
