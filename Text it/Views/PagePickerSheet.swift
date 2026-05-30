//
//  PagePickerSheet.swift
//  Text it
//
//  Seiten-Auswahl für Seitenlinks (pagelink-Block).
//

import SwiftUI
import SwiftData

struct PagePickerSheet: View {
    var onPick: (UUID) -> Void
    var onCreate: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<Page> { !$0.isTrashed },
        sort: \Page.updatedAt,
        order: .reverse
    )
    private var pages: [Page]

    @State private var search: String = ""

    private var filtered: [Page] {
        if search.isEmpty { return Array(pages.prefix(40)) }
        return pages.filter {
            $0.title.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Suchfeld
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Seite suchen…", text: $search)
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filtered) { page in
                        Button {
                            onPick(page.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: page.icon)
                                    .frame(width: 26, height: 26)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(page.title.isEmpty ? "Unbenannt" : page.title)
                                        .lineLimit(1)
                                    if let parent = page.parent {
                                        Text(parent.title.isEmpty ? "Unbenannt" : parent.title)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if filtered.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                            Text("Keine Seite gefunden")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                }
            }

            Divider()

            HStack {
                if let create = onCreate {
                    Button {
                        create()
                        dismiss()
                    } label: {
                        Label("Neue Seite erstellen & verlinken", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(minWidth: 360, minHeight: 440)
    }
}
