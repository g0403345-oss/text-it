//
//  TagsView.swift
//  Text it
//
//  Tag-Browser: alle Tags über alle Seiten, mit Seiten-Filterung.
//

import SwiftUI
import SwiftData

struct TagsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Page> { !$0.isTrashed })
    private var allPages: [Page]

    @State private var selectedTag: String? = nil
    @State private var searchText: String = ""

    private var tagCounts: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for page in allPages {
            for tag in page.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
            .map { (tag: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var filteredTagCounts: [(tag: String, count: Int)] {
        guard !searchText.isEmpty else { return tagCounts }
        return tagCounts.filter { $0.tag.localizedCaseInsensitiveContains(searchText) }
    }

    private var pagesForSelectedTag: [Page] {
        guard let tag = selectedTag else { return [] }
        return allPages
            .filter { $0.tags.contains(tag) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tags")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("\(tagCounts.count) Tags in \(allPages.count) Seiten")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if tagCounts.isEmpty {
                    emptyState
                } else {
                    // Suche
                    searchField

                    // Tag-Cloud
                    tagCloud

                    // Seiten des ausgewählten Tags
                    if let tag = selectedTag {
                        selectedTagPages(tag: tag)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .navigationTitle("Tags")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag.slash")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text("Noch keine Tags")
                .font(.title3.weight(.semibold))
            Text("Füge Tags zu Seiten hinzu, um sie hier zu sehen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Suche

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Tag suchen…", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary.opacity(0.5))
        )
    }

    // MARK: - Tag Cloud

    private var tagCloud: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Alle Tags", icon: "tag.fill")
            FlowLayout(spacing: 10) {
                ForEach(filteredTagCounts, id: \.tag) { item in
                    TagChip(
                        tag: item.tag,
                        count: item.count,
                        isSelected: selectedTag == item.tag
                    ) {
                        withAnimation(.spring(response: 0.25)) {
                            selectedTag = selectedTag == item.tag ? nil : item.tag
                        }
                    }
                }
            }
        }
    }

    // MARK: - Pages for Tag

    @ViewBuilder
    private func selectedTagPages(tag: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Seiten mit \"\(tag)\"", icon: "doc.text.fill")
                Spacer()
                Button {
                    withAnimation { selectedTag = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if pagesForSelectedTag.isEmpty {
                Text("Keine Seiten mit diesem Tag")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(pagesForSelectedTag) { page in
                    TaggedPageRow(page: page) {
                        appState.navigateTo(pageID: page.id)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.quaternary.opacity(0.3))
        )
        .transition(.asymmetric(
            insertion: .scale(scale: 0.96).combined(with: .opacity),
            removal: .opacity
        ))
    }
}

// MARK: - TagChip

struct TagChip: View {
    let tag: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .font(.caption2)
                Text(tag)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                Text("\(count)")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.white.opacity(isSelected ? 0.3 : 0.0)))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                    .overlay(
                        Capsule().stroke(Color.accentColor.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - TaggedPageRow

struct TaggedPageRow: View {
    let page: Page
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: page.icon)
                    .font(.body)
                    .foregroundStyle(.tint)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(page.title.isEmpty ? "Unbenannt" : page.title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(page.updatedAt.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Tags der Seite
                HStack(spacing: 4) {
                    ForEach(page.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                            .foregroundStyle(.tint)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FlowLayout (Tag-Cloud Layout)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight = currentY + rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        _ = maxWidth
    }
}
