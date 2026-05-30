//
//  SlashMenuView.swift
//  Text it
//

import SwiftUI

struct SlashMenuView: View {
    var onPick: (BlockType) -> Void

    @State private var search: String = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [BlockType] {
        if search.isEmpty { return BlockType.allCases }
        return BlockType.allCases.filter {
            $0.title.localizedCaseInsensitiveContains(search) ||
            $0.rawValue.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Blocktyp suchen…", text: $search)
                    .textFieldStyle(.plain)
            }
            .padding(12)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filtered) { type in
                        Button {
                            onPick(type)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: type.systemImage)
                                    .frame(width: 28, height: 28)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading) {
                                    Text(type.title).font(.body)
                                    if !type.shortcut.isEmpty {
                                        Text("Tippe „\(type.shortcut)“ + Leertaste")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Divider()
            HStack {
                Button("Abbrechen") { dismiss() }
                Spacer()
            }.padding(8)
        }
    }
}
