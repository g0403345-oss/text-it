//
//  ImageBlockView.swift
//  Text it
//
//  Bild-Block mit:
//  - Größenänderung per Drag-Handle (rechte Seite)
//  - Screenshot einfügen per Drag & Drop oder Paste
//

import SwiftUI
import SwiftData
#if os(iOS) || os(visionOS)
import UIKit
import PhotosUI
#elseif os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

// Misst die Containerbreite im Hintergrund (vermeidet GeometryReader als Root-Element)
private struct ImageContainerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ImageBlockView: View {
    @Bindable var block: Block
    @Environment(\.modelContext) private var context

    #if os(iOS) || os(visionOS)
    @State private var pickerItem: PhotosPickerItem? = nil
    #endif

    @State private var isDragTarget: Bool = false
    @GestureState private var resizeDrag: CGFloat = 0
    @State private var containerWidth: CGFloat = 800  // Standardwert; wird via PreferenceKey gesetzt

    private let minFrac: Double = 0.15
    private let maxFrac: Double = 1.0

    var body: some View {
        let frac = max(minFrac, min(maxFrac, block.imageWidth + resizeDrag / max(1, containerWidth)))
        let imageWidth = containerWidth * frac

        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .trailing) {
                imageContent(width: imageWidth)
                    .frame(width: imageWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isDragTarget ? Color.accentColor : Color.clear, lineWidth: 2)
                    )

                resizeHandle(containerWidth: containerWidth)
                    .offset(x: 8)
                    .frame(width: imageWidth, alignment: .trailing)
            }

            // Caption + Picker-Buttons
            HStack(spacing: 8) {
                #if os(iOS) || os(visionOS)
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Wählen", systemImage: "photo")
                        .font(.caption)
                }
                .onChange(of: pickerItem) { _, item in
                    Task {
                        if let data = try? await item?.loadTransferable(type: Data.self) {
                            block.imageData = data
                            try? context.save()
                        }
                    }
                }
                #elseif os(macOS)
                Button { pickImageMac() } label: {
                    Label("Wählen", systemImage: "photo")
                        .font(.caption)
                }
                #endif

                if block.imageData != nil {
                    Menu {
                        Button("25%")  { setWidth(0.25) }
                        Button("50%")  { setWidth(0.50) }
                        Button("75%")  { setWidth(0.75) }
                        Button("100%") { setWidth(1.00) }
                    } label: {
                        Text("\(Int(frac * 100))%")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 44)
                }

                TextField("Bildunterschrift", text: $block.text)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Breite im Hintergrund messen — GeometryReader als Hintergrund
        // vermeidet Layout-Probleme (falsche Höhe / Null-Breite) die entstehen
        // wenn GeometryReader als Root-Element in UIKit-basierten ScrollViews verwendet wird.
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: ImageContainerWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(ImageContainerWidthKey.self) { w in
            if w > 10 { containerWidth = w }
        }
        .onDrop(of: [.image, .fileURL, .png, .jpeg, .tiff], isTargeted: $isDragTarget) { providers in
            handleDrop(providers: providers)
        }
        #if os(macOS)
        .onPasteCommand(of: [.image, .png, .jpeg, .tiff]) { providers in
            handleDrop(providers: providers)
        }
        #endif
    }

    // MARK: - Image Content

    @ViewBuilder
    private func imageContent(width: CGFloat) -> some View {
        if let data = block.imageData, let img = platformImage(from: data) {
            #if os(macOS)
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: width)
            #else
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: width)
            #endif
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(height: 150)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: isDragTarget ? "arrow.down.circle" : "photo.badge.plus")
                            .font(.title)
                            .foregroundStyle(isDragTarget ? Color.accentColor : Color.secondary)
                        Text(isDragTarget ? "Loslassen zum Einfügen" : "Bild wählen oder hierher ziehen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
        }
    }

    // MARK: - Resize Handle

    private func resizeHandle(containerWidth: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.secondary.opacity(0.5))
            .frame(width: 6, height: 36)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .updating($resizeDrag) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let newFrac = max(minFrac, min(maxFrac,
                            block.imageWidth + value.translation.width / max(1, containerWidth)))
                        block.imageWidth = newFrac
                        try? context.save()
                    }
            )
            .contentShape(Rectangle().inset(by: -8))
    }

    // MARK: - Drop Handler

    @discardableResult
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        #if os(macOS)
        if provider.canLoadObject(ofClass: NSImage.self) {
            provider.loadObject(ofClass: NSImage.self) { obj, _ in
                if let img = obj as? NSImage,
                   let tiff = img.tiffRepresentation,
                   let bmp = NSBitmapImageRep(data: tiff),
                   let png = bmp.representation(using: .png, properties: [:]) {
                    DispatchQueue.main.async {
                        block.imageData = png
                        try? context.save()
                    }
                }
            }
            return true
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                if let url = item as? URL, let data = try? Data(contentsOf: url) {
                    DispatchQueue.main.async {
                        block.imageData = data
                        try? context.save()
                    }
                }
            }
            return true
        }
        #else
        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { obj, _ in
                if let img = obj as? UIImage, let data = img.pngData() {
                    DispatchQueue.main.async {
                        block.imageData = data
                        try? context.save()
                    }
                }
            }
            return true
        }
        #endif
        return false
    }

    // MARK: - Helpers

    private func setWidth(_ frac: Double) {
        block.imageWidth = frac
        try? context.save()
    }

    #if os(macOS)
    private func pickImageMac() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            block.imageData = data
            try? context.save()
        }
    }
    #endif

    private func platformImage(from data: Data) -> PlatformImage? {
        #if os(macOS)
        return NSImage(data: data)
        #else
        return UIImage(data: data)
        #endif
    }
}

#if os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = UIImage
#endif
