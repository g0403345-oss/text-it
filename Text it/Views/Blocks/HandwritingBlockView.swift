//
//  HandwritingBlockView.swift
//  Text it
//
//  HINWEIS: Mit Version 2 wird die Apple-Pencil-Handschrift als
//  SEITENWEITES Overlay über alle Blöcke gelegt (siehe PageEditorView).
//  Dieser Block existiert nur noch als read-only Vorschau alter Daten.
//

import SwiftUI
import SwiftData
import PencilKit

struct HandwritingBlockView: View {
    @Bindable var block: Block
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "applepencil.tip")
                Text("Schreibe einfach mit dem Apple Pencil direkt auf die Seite – über jedem Text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.quaternary)

                if let data = block.drawingData,
                   !data.isEmpty,
                   let drawing = try? PKDrawing(data: data) {
                    DrawingThumb(drawing: drawing)
                        .padding(8)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "applepencil.and.scribble")
                            .font(.title2)
                        Text("Tippe oben in der Toolbar auf das Pencil-Symbol, dann schreibe direkt auf das Blatt.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.secondary)
                    .padding()
                }
            }
            .frame(minHeight: 140)

            TextField("Beschriftung", text: $block.text)
                .textFieldStyle(.plain)
                .font(.caption)
        }
    }
}

private struct DrawingThumb: View {
    let drawing: PKDrawing
    var body: some View {
        GeometryReader { geo in
            let bounds = drawing.bounds.isEmpty
                ? CGRect(origin: .zero, size: geo.size)
                : drawing.bounds.insetBy(dx: -8, dy: -8)
            #if canImport(UIKit)
            let img = drawing.image(from: bounds, scale: UIScreen.main.scale)
            Image(uiImage: img).resizable().scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            #else
            let img = drawing.image(from: bounds, scale: 2.0)
            Image(nsImage: img).resizable().scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            #endif
        }
        .frame(minHeight: 120)
    }
}
