//
//  TableBlockView.swift
//  Text it
//

import SwiftUI
import SwiftData

struct TableBlockView: View {
    @Bindable var block: Block
    @Environment(\.modelContext) private var context

    struct TableData: Codable {
        var rows: [[String]]
        static let empty = TableData(rows: [["", ""], ["", ""]])
    }

    private var data: TableData {
        get {
            if let d = block.jsonPayload,
               let t = try? JSONDecoder().decode(TableData.self, from: d) {
                return t
            }
            return .empty
        }
    }

    @State private var local: TableData = .empty

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(local.rows.indices, id: \.self) { r in
                HStack(spacing: 4) {
                    ForEach(local.rows[r].indices, id: \.self) { c in
                        TextField("", text: Binding(
                            get: { local.rows[r][c] },
                            set: { local.rows[r][c] = $0; persist() }
                        ))
                        .textFieldStyle(.plain)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.3))
                    }
                }
            }
            HStack {
                Button("+ Zeile") {
                    let cols = local.rows.first?.count ?? 2
                    local.rows.append(Array(repeating: "", count: cols))
                    persist()
                }
                Button("+ Spalte") {
                    for i in local.rows.indices { local.rows[i].append("") }
                    persist()
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .onAppear {
            local = data
        }
    }

    private func persist() {
        block.jsonPayload = try? JSONEncoder().encode(local)
        block.updatedAt = Date()
        try? context.save()
    }
}
