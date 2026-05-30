//
//  SearchView.swift
//  Text it
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<Page> { !$0.isTrashed })
    private var pages: [Page]
    @Query private var blocks: [Block]

    @State private var query: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Seiten und Inhalte suchen…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
            }
            .padding(14)
            Divider()
            List {
                Section("Seiten") {
                    ForEach(filteredPages) { page in
                        Button {
                            appState.selectedPageID = page.id
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: page.icon)
                                Text(page.title.isEmpty ? "Unbenannt" : page.title)
                                Spacer()
                                Text(page.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section("Inhalte") {
                    ForEach(filteredBlocks) { block in
                        Button {
                            if let pid = block.page?.id {
                                appState.selectedPageID = pid
                                dismiss()
                            }
                        } label: {
                            VStack(alignment: .leading) {
                                Text(block.page?.title ?? "Unbenannt").font(.caption).foregroundStyle(.secondary)
                                Text(block.text).lineLimit(2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var filteredPages: [Page] {
        guard !query.isEmpty else { return Array(pages.prefix(20)) }
        return pages.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private var filteredBlocks: [Block] {
        guard !query.isEmpty else { return [] }
        return blocks.filter { !$0.text.isEmpty && $0.text.localizedCaseInsensitiveContains(query) }
    }
}
