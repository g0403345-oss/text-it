//
//  PDFBlockView.swift
//  Text it
//
//  PDF-Block: Importieren, Anzeigen, Mit Apple Pencil annotieren.
//  – iPad/iOS: PDFAnnotationContainer (UIView) mit überlagerndem PKCanvasView
//    → hitTest leitet Finger-Touches an PDFView weiter (Scrollen),
//      Apple-Pencil-Touches gehen zum Canvas (Zeichnen)
//  – macOS: PDFView ohne Annotation
//  – Höhe ist frei ziehbar über einen Drag-Handle am unteren Rand
//  – "Als neue Unterseite" erstellt eine Unterseite mit diesem PDF
//

import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers
#if os(iOS) || os(visionOS)
import UIKit
import PencilKit
#elseif os(macOS)
import AppKit
#endif

struct PDFBlockView: View {
    @Bindable var block: Block
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @State private var showFilePicker = false
    @State private var showFullscreen = false
    @State private var pdfDoc: PDFDocument?
    @GestureState private var resizeDrag: CGFloat = 0

    private let minHeight: CGFloat = 300
    private let maxHeight: CGFloat = 3000

    private var blockHeight: CGFloat {
        let dragged = CGFloat(block.pdfBlockHeight) + resizeDrag
        return max(minHeight, min(maxHeight, dragged))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let doc = pdfDoc {
                pdfToolbar(doc: doc)
                Divider()
                pdfViewer(doc: doc)
                    .frame(height: blockHeight)
                Divider()
                resizeHandle
            } else {
                placeholder
            }
        }
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
        .onAppear {
            if let data = block.pdfData {
                pdfDoc = PDFDocument(data: data)
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false,
            onCompletion: importPDF
        )
        .sheet(isPresented: $showFullscreen) {
            if let doc = pdfDoc {
                PDFFullscreenView(
                    title: block.text.isEmpty ? "PDF" : block.text,
                    document: doc,
                    drawingData: Binding(
                        get: { block.drawingData },
                        set: { block.drawingData = $0; try? context.save() }
                    )
                )
                .environment(appState)
            }
        }
    }

    // MARK: – Toolbar

    private func pdfToolbar(doc: PDFDocument) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .foregroundStyle(appState.theme.accent)
            Text(block.text.isEmpty ? "PDF" : block.text)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Text("·  \(doc.pageCount) Seite\(doc.pageCount == 1 ? "" : "n")")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            #if os(iOS) || os(visionOS)
            Label("Pencil annotiert", systemImage: "applepencil.tip")
                .font(.caption2)
                .foregroundStyle(appState.theme.accent.opacity(0.7))
                .labelStyle(.titleAndIcon)
            #endif

            Button { showFullscreen = true } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help("Vollbild öffnen")

            Button { createPDFPage() } label: {
                Image(systemName: "plus.square.on.square")
            }
            .help("Als neue Unterseite erstellen")

            Button { showFilePicker = true } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .help("PDF ersetzen")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: – Viewer

    @ViewBuilder
    private func pdfViewer(doc: PDFDocument) -> some View {
        #if os(iOS) || os(visionOS)
        PDFAnnotationView(
            document: doc,
            drawingData: Binding(
                get: { block.drawingData },
                set: { block.drawingData = $0; try? context.save() }
            )
        )
        #else
        PDFKitRepresentable(document: doc)
        #endif
    }

    // MARK: – Resize Handle (unten ziehen)

    private var resizeHandle: some View {
        HStack {
            Spacer()
            Image(systemName: "line.3.horizontal")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(height: 18)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .updating($resizeDrag) { value, state, _ in
                    state = value.translation.height
                }
                .onEnded { value in
                    let newH = CGFloat(block.pdfBlockHeight) + value.translation.height
                    block.pdfBlockHeight = Double(max(minHeight, min(maxHeight, newH)))
                    try? context.save()
                }
        )
        #if os(macOS)
        .onHover { hovering in
            NSCursor.resizeUpDown.set()
            if !hovering { NSCursor.arrow.set() }
        }
        #endif
    }

    // MARK: – Placeholder

    private var placeholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("PDF importieren")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            #if os(iOS) || os(visionOS)
            Text("Apple Pencil-Annotationen werden gespeichert")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            #endif
            Button { showFilePicker = true } label: {
                Label("PDF wählen", systemImage: "folder.badge.plus")
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    // MARK: – Import

    private func importPDF(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        block.pdfData = data
        if block.text.isEmpty {
            block.text = url.deletingPathExtension().lastPathComponent
        }
        let doc = PDFDocument(data: data)
        pdfDoc = doc
        // Höhe automatisch an Seitenanzahl anpassen (erste Schätzung)
        if let d = doc {
            let estimate = min(Double(d.pageCount) * 500, 2000)
            block.pdfBlockHeight = max(700, estimate)
        }
        try? context.save()
    }

    // MARK: – Als neue Unterseite erstellen

    private func createPDFPage() {
        guard let data = block.pdfData else { return }
        let newPage = Page(
            title: block.text.isEmpty ? "PDF-Dokument" : block.text,
            icon: "doc.richtext",
            parent: block.page,
            workspace: block.page?.workspace
        )
        context.insert(newPage)

        let pdfBlock = Block(type: .pdf, text: block.text, sortIndex: 0, page: newPage)
        pdfBlock.pdfData = data
        pdfBlock.drawingData = block.drawingData
        pdfBlock.pdfBlockHeight = block.pdfBlockHeight
        context.insert(pdfBlock)

        try? context.save()
        appState.navigateTo(pageID: newPage.id)
    }
}

// MARK: – iOS/visionOS: PDFView + PKCanvasView (Pencil → Canvas, Finger → PDF)

#if os(iOS) || os(visionOS)

struct PDFAnnotationView: UIViewRepresentable {
    var document: PDFDocument
    @Binding var drawingData: Data?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PDFAnnotationContainer {
        let c = PDFAnnotationContainer(document: document)
        c.canvasView.delegate = context.coordinator
        context.coordinator.container = c
        if let d = drawingData, let drawing = try? PKDrawing(data: d) {
            c.canvasView.drawing = drawing
        }
        return c
    }

    func updateUIView(_ c: PDFAnnotationContainer, context: Context) {
        if c.pdfView.document !== document {
            c.pdfView.document = document
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PDFAnnotationView
        weak var container: PDFAnnotationContainer?
        init(_ p: PDFAnnotationView) { parent = p }

        func canvasViewDrawingDidChange(_ cv: PKCanvasView) {
            parent.drawingData = cv.drawing.dataRepresentation()
        }
    }
}

final class PDFAnnotationContainer: UIView {
    let pdfView = PDFView()
    let canvasView = PKCanvasView()

    init(document: PDFDocument) {
        super.init(frame: .zero)
        setupPDF(document: document)
        setupCanvas()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupPDF(document: PDFDocument) {
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor.systemBackground
        addSubview(pdfView)
        pin(pdfView)
    }

    private func setupCanvas() {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        // pencilOnly: nur Apple-Pencil zeichnet, Finger-Events werden weitergeleitet
        canvasView.drawingPolicy = .pencilOnly
        canvasView.tool = PKInkingTool(.pen, color: .systemBlue, width: 2)
        // Canvas als Overlay: liegt über PDFView, aber scrollt nicht selbst
        canvasView.isScrollEnabled = false
        addSubview(canvasView)
        pin(canvasView)
    }

    // MARK: – hitTest-Routing
    // Finger-Touches → PDFView (scrollt)
    // Apple-Pencil-Touches → PKCanvasView (zeichnet)
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hasPencil = event?.allTouches?.contains(where: { $0.type == .stylus }) ?? false
        if hasPencil {
            return canvasView.hitTest(convert(point, to: canvasView), with: event)
        }
        // Finger: weiterleiten an PDFView (erlaubt Scrollen durch das Dokument)
        let pdfPoint = convert(point, to: pdfView)
        if let hit = pdfView.hitTest(pdfPoint, with: event) {
            return hit
        }
        return super.hitTest(point, with: event)
    }

    private func pin(_ v: UIView) {
        v.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: topAnchor),
            v.leadingAnchor.constraint(equalTo: leadingAnchor),
            v.trailingAnchor.constraint(equalTo: trailingAnchor),
            v.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}

#endif

// MARK: – macOS: NSViewRepresentable

#if os(macOS)

struct PDFKitRepresentable: NSViewRepresentable {
    var document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let v = PDFView()
        v.document = document
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        return v
    }

    func updateNSView(_ v: PDFView, context: Context) {
        if v.document !== document { v.document = document }
    }
}

#endif

// MARK: – Vollbild-Ansicht

struct PDFFullscreenView: View {
    var title: String
    var document: PDFDocument
    @Binding var drawingData: Data?
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "doc.richtext")
                    .foregroundStyle(appState.theme.accent)
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Fertig") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Divider()

            #if os(iOS) || os(visionOS)
            PDFAnnotationView(document: document, drawingData: $drawingData)
                .ignoresSafeArea(edges: .bottom)
            #else
            PDFKitRepresentable(document: document)
            #endif
        }
    }
}
