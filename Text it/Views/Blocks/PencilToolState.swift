//
//  PencilToolState.swift
//  Text it
//
//  Globale Werkzeug-Einstellung für die Apple-Pencil-Overlays
//  (analog zu GoodNotes: Stift, Marker, Radierer, Farbe, Strichstärke …).
//

import SwiftUI
import PencilKit

@MainActor
@Observable
final class PencilToolState {
    static let shared = PencilToolState()

    #if os(iOS) || os(visionOS)
    /// Direkte Referenz auf die aktive PKCanvasView — für Undo/Redo.
    weak var canvas: PKCanvasView?
    #endif

    enum Tool: String, CaseIterable, Identifiable {
        case pen, pencil, marker, monoline, fountainPen, eraser, lasso
        var id: String { rawValue }

        var title: String {
            switch self {
            case .pen: return "Stift"
            case .pencil: return "Bleistift"
            case .marker: return "Textmarker"
            case .monoline: return "Monoline"
            case .fountainPen: return "Füllfeder"
            case .eraser: return "Radierer"
            case .lasso: return "Auswahl"
            }
        }

        var systemImage: String {
            switch self {
            case .pen: return "pencil.tip"
            case .pencil: return "pencil"
            case .marker: return "highlighter"
            case .monoline: return "scribble"
            case .fountainPen: return "pencil.and.outline"
            case .eraser: return "eraser"
            case .lasso: return "lasso"
            }
        }
    }

    enum EraserMode: String { case vector, pixel }

    /// Das zuletzt aktive Nicht-Radierer-Werkzeug – für Doppeltippen-Toggle.
    var lastNonEraserTool: Tool = .pen

    var tool: Tool = .pen {
        didSet {
            if oldValue != .eraser { lastNonEraserTool = oldValue }
            version &+= 1
        }
    }
    var color: Color = .black {
        didSet { version &+= 1 }
    }
    var width: CGFloat = 2.5 {
        didSet { version &+= 1 }
    }
    var eraserMode: EraserMode = .vector {
        didSet { version &+= 1 }
    }
    var shapeRecognition: Bool = true {
        didSet { version &+= 1 }
    }
    var inkOpacity: Double = 1.0 {
        didSet { version &+= 1 }
    }
    /// Monoton steigender Zähler – triggert SwiftUI-Updates in Views,
    /// die den Tool-Snapshot konsumieren.
    var version: Int = 0

    // Farbpalette
    let palette: [Color] = [
        .black, .gray,
        .red, .orange, .yellow,
        .green, .mint, .teal,
        .blue, .indigo, .purple, .pink,
        Color(red: 0.55, green: 0.35, blue: 0.15) // braun
    ]

    let widths: [CGFloat] = [1.5, 3.0, 6.0, 12.0]

    /// Liefert das PencilKit-Tool für den aktuellen Zustand.
    func makePKTool() -> PKTool {
        let uiColor = PlatformColorAdapter.color(from: color)
        let opacity = CGFloat(inkOpacity)
        switch tool {
        case .pen:         return PKInkingTool(.pen,        color: uiColor.withAlpha(opacity), width: width)
        case .pencil:      return PKInkingTool(.pencil,     color: uiColor.withAlpha(opacity), width: width)
        case .marker:      return PKInkingTool(.marker,     color: uiColor.withAlpha(0.4 * opacity), width: max(width, 8))
        case .monoline:    return PKInkingTool(.monoline,   color: uiColor.withAlpha(opacity), width: width)
        case .fountainPen: return PKInkingTool(.fountainPen,color: uiColor.withAlpha(opacity), width: width)
        case .eraser:      return PKEraserTool(eraserMode == .vector ? .vector : .bitmap, width: max(width * 3, 12))
        case .lasso:       return PKLassoTool()
        }
    }
}

// MARK: - Plattformfarben

#if canImport(UIKit)
import UIKit
typealias NativeColor = UIColor
extension UIColor {
    func withAlpha(_ a: CGFloat) -> UIColor { self.withAlphaComponent(a) }
}
#elseif canImport(AppKit)
import AppKit
typealias NativeColor = NSColor
extension NSColor {
    func withAlpha(_ a: CGFloat) -> NSColor { self.withAlphaComponent(a) }
}
#endif

enum PlatformColorAdapter {
    static func color(from swiftUIColor: Color) -> NativeColor {
        #if canImport(UIKit)
        return UIColor(swiftUIColor)
        #else
        return NSColor(swiftUIColor)
        #endif
    }
}
