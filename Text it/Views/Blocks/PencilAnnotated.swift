//
//  PencilAnnotated.swift
//  Text it
//
//  Seitenweites Apple-Pencil-Layer:
//  - Auf iPad/visionOS zeichnet der Apple Pencil ÜBERALL auf der Seite.
//  - Finger und Tastatur "fallen durch" zu den eigentlichen Textfeldern.
//  - Speichern passiert in canvasViewDidEndUsingTool (= Pencil abgehoben),
//    nicht im 0,15s-Debounce — so wird Formerkennung nicht unterbrochen.
//

import SwiftUI
import PencilKit

// MARK: - Plattform-übergreifende, read-only Bild-Vorschau einer PKDrawing
struct PageDrawingImage: View {
    let data: Data

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            if size.width > 1, size.height > 1,
               let drawing = try? PKDrawing(data: data) {
                let rect = CGRect(origin: .zero, size: size)
                #if canImport(UIKit)
                let img = drawing.image(from: rect, scale: UIScreen.main.scale)
                Image(uiImage: img)
                    .resizable()
                    .frame(width: size.width, height: size.height)
                #else
                let img = drawing.image(from: rect, scale: 2.0)
                Image(nsImage: img)
                    .resizable()
                    .frame(width: size.width, height: size.height)
                #endif
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

#if os(iOS) || os(visionOS)
import UIKit

// MARK: - PKCanvasView, der NUR Pencil-Touches einfängt
final class PencilOnlyHitCanvas: PKCanvasView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let event = event,
              let touches = event.allTouches,
              !touches.isEmpty else {
            return super.hitTest(point, with: event)
        }
        if touches.contains(where: { $0.type == .pencil }) {
            return super.hitTest(point, with: event)
        }
        return nil
    }
}

// MARK: - Seitenweites Pencil-Canvas (iPad/visionOS)
struct PageHandwritingCanvas: UIViewRepresentable {
    @Binding var data: Data?
    var tool: PKTool
    var toolVersion: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PencilOnlyHitCanvas()
        canvas.drawingPolicy = .pencilOnly
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.tool = tool
        canvas.delegate = context.coordinator
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false
        canvas.bounces = false
        canvas.isScrollEnabled = false
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.maximumZoomScale = 1
        canvas.minimumZoomScale = 1

        if let d = data, !d.isEmpty, let drawing = try? PKDrawing(data: d) {
            canvas.drawing = drawing
        }

        // Undo-Manager für Toolbar-Buttons zugänglich machen
        DispatchQueue.main.async { [weak canvas] in
            PencilToolState.shared.canvas = canvas
        }

        // Scroll-Gesten der übergeordneten UIScrollViews auf Finger/Zeiger beschränken,
        // damit Pencil-Striche nicht als Scroll-Geste fehlinterpretiert werden.
        DispatchQueue.main.async { [weak canvas] in
            Self.disablePencilScrolling(from: canvas)
        }

        return canvas
    }

    private static func disablePencilScrolling(from view: UIView?) {
        var current = view?.superview
        while let parent = current {
            if let sv = parent as? UIScrollView, !(sv is PKCanvasView) {
                sv.panGestureRecognizer.allowedTouchTypes = [
                    NSNumber(value: UITouch.TouchType.direct.rawValue),
                    NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)
                ]
            }
            current = parent.superview
        }
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Immer zuerst: Coordinator auf aktuelle Seite zeigen lassen.
        // Ohne das schreibt canvasViewDidEndUsingTool in die Seite vor der Navigation.
        context.coordinator.parent = self

        uiView.tool = tool

        let bytes = data ?? Data()
        let coordinator = context.coordinator

        // Leere Seite: Canvas programmatisch leeren und isUserDrawing zurücksetzen,
        // damit beim nächsten Seitenwechsel die Zeichnung der neuen Seite korrekt lädt.
        if bytes.isEmpty {
            if !uiView.drawing.strokes.isEmpty {
                coordinator.isProgrammaticChange = true
                uiView.drawing = PKDrawing()
                coordinator.isProgrammaticChange = false
            }
            coordinator.isUserDrawing = false
            return
        }

        // Während aktiver Zeichnung/Formerkennung: nicht überschreiben.
        guard !coordinator.isUserDrawing else { return }
        if let incoming = try? PKDrawing(data: bytes),
           incoming.dataRepresentation() != uiView.drawing.dataRepresentation() {
            coordinator.isProgrammaticChange = true
            uiView.drawing = incoming
            coordinator.isProgrammaticChange = false
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        // var statt let — wird in updateUIView aktualisiert, damit canvasViewDidEndUsingTool
        // immer in die aktuell angezeigte Seite schreibt, nicht in die Seite beim ersten Render.
        var parent: PageHandwritingCanvas
        /// True vom ersten Pencil-Kontakt bis kurz nach dem Abheben.
        var isUserDrawing = false
        /// True während programmatischer Canvas-Änderungen (updateUIView),
        /// damit canvasViewDrawingDidChange nicht isUserDrawing setzt.
        var isProgrammaticChange = false

        init(_ parent: PageHandwritingCanvas) { self.parent = parent }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            isUserDrawing = true
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isProgrammaticChange else { return }
            isUserDrawing = true
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            let bytes = canvasView.drawing.dataRepresentation()
            parent.data = bytes.isEmpty ? nil : bytes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.isUserDrawing = false
            }
        }
    }
}

#endif
