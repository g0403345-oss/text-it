//
//  PencilToolbar.swift
//  Text it
//
//  Kompakte, schwimmende Apple-Pencil-Werkzeugleiste — NUR auf iPad/iOS.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import PencilKit

struct PencilToolbar: View {
    @State private var state = PencilToolState.shared

    // Hauptwerkzeuge (sichtbar in der Toolbar)
    private let mainTools: [PencilToolState.Tool] = [.pen, .pencil, .marker, .eraser, .lasso]

    // Farbpalette (8 Schnellfarben)
    private let quickColors: [Color] = [
        .black, .gray, .red, .orange, .blue, .green, .purple, .pink
    ]

    var body: some View {
        HStack(spacing: 0) {
            undoRedoGroup
            sep
            toolGroup
            sep
            widthGroup
            sep
            colorGroup
            sep
            opacityGroup
            sep
            extrasGroup
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(.quaternary, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 5)
        .frame(maxWidth: 720)
        .animation(.easeInOut(duration: 0.15), value: state.tool)
        .animation(.easeInOut(duration: 0.15), value: state.inkOpacity)
    }

    // MARK: - Undo / Redo

    private var undoRedoGroup: some View {
        HStack(spacing: 2) {
            iconButton("arrow.uturn.backward") {
                // Direkt über den Canvas-UndoManager — funktioniert auch wenn Canvas
                // nicht first responder ist (Toolbar-Tap mit Finger).
                state.canvas?.undoManager?.undo()
            }
            .help("Rückgängig")
            iconButton("arrow.uturn.forward") {
                state.canvas?.undoManager?.redo()
            }
            .help("Wiederholen")
        }
    }

    // MARK: - Werkzeuge

    private var toolGroup: some View {
        HStack(spacing: 2) {
            ForEach(mainTools) { tool in
                Button {
                    state.tool = tool
                } label: {
                    Image(systemName: tool.systemImage)
                        .font(.system(size: 14, weight: .regular))
                        .frame(width: 30, height: 28)
                        .background(
                            state.tool == tool
                                ? Color.accentColor.opacity(0.18)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 7)
                        )
                        .foregroundStyle(state.tool == tool ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
                .help(tool.title)
            }
        }
    }

    // MARK: - Strichbreite

    private var widthGroup: some View {
        HStack(spacing: 3) {
            ForEach(state.widths, id: \.self) { w in
                Button { state.width = w } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isActiveWidth(w) ? Color.accentColor.opacity(0.18) : Color.clear)
                        Circle()
                            .fill(Color.primary)
                            .frame(width: dotSize(w), height: dotSize(w))
                    }
                    .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Strichbreite \(Int(w))pt")
            }
        }
    }

    private func dotSize(_ w: CGFloat) -> CGFloat { min(4 + w * 0.9, 14) }
    private func isActiveWidth(_ w: CGFloat) -> Bool { abs(state.width - w) < 1.0 }

    // MARK: - Farben

    private var colorGroup: some View {
        HStack(spacing: 3) {
            ForEach(Array(quickColors.enumerated()), id: \.offset) { _, color in
                Button { state.color = color } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.primary.opacity(0.12), lineWidth: 0.5))
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: state.color == color ? 2 : 0)
                                .padding(-3)
                        )
                }
                .buttonStyle(.plain)
            }
            // Beliebige Farbe
            ColorPicker("", selection: Binding(
                get: { state.color },
                set: { state.color = $0 }
            ))
            .labelsHidden()
            .frame(width: 20, height: 20)
        }
    }

    // MARK: - Deckkraft (3 Stufen)

    private var opacityGroup: some View {
        HStack(spacing: 3) {
            ForEach([0.25, 0.5, 1.0], id: \.self) { op in
                Button { state.inkOpacity = op } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isActiveOpacity(op) ? Color.accentColor.opacity(0.18) : Color.clear)
                        // Kreis mit der aktuellen Farbe in der jeweiligen Deckkraft
                        Circle()
                            .fill(state.color.opacity(op))
                            .frame(width: 11, height: 11)
                            .overlay(Circle().stroke(.primary.opacity(0.2), lineWidth: 0.5))
                    }
                    .frame(width: 24, height: 26)
                }
                .buttonStyle(.plain)
                .help("\(Int(op * 100)) % Deckkraft")
            }
        }
    }

    private func isActiveOpacity(_ op: Double) -> Bool { abs(state.inkOpacity - op) < 0.1 }

    // MARK: - Extras: Formerkennung + Radierer-Modus

    private var extrasGroup: some View {
        HStack(spacing: 4) {
            // Linien glätten / Formerkennung (Strich halten = einrasten)
            Button {
                state.shapeRecognition.toggle()
            } label: {
                Image(systemName: state.shapeRecognition ? "ruler.fill" : "ruler")
                    .font(.system(size: 14))
                    .frame(width: 30, height: 28)
                    .background(
                        state.shapeRecognition
                            ? Color.accentColor.opacity(0.18)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7)
                    )
                    .foregroundStyle(state.shapeRecognition ? Color.accentColor : Color.primary)
            }
            .buttonStyle(.plain)
            .help("Formen einrasten (Strich halten zum Glätten)")

            // Radierer-Modus (nur sichtbar wenn Radierer aktiv)
            if state.tool == .eraser {
                Button {
                    state.eraserMode = state.eraserMode == .vector ? .pixel : .vector
                } label: {
                    Text(state.eraserMode == .vector ? "Obj" : "Px")
                        .font(.caption2.weight(.semibold))
                        .frame(width: 30, height: 28)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help(state.eraserMode == .vector ? "Objekt-Radierer" : "Pixel-Radierer")
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Helpers

    private var sep: some View {
        Divider()
            .frame(height: 20)
            .padding(.horizontal, 6)
    }

    private func iconButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .regular))
                .frame(width: 28, height: 28)
                .foregroundStyle(Color.primary)
        }
        .buttonStyle(.plain)
    }
}
#endif
