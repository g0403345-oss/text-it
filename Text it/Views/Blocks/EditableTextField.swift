//
//  EditableTextField.swift
//  Text it
//
//  Editor-Textfeld mit Slash-/Markdown-Erkennung.
//  Auf iPad/iOS: Apple Pencil wird NIE in Text gewandelt (Scribble entfernt).
//

import SwiftUI

struct EditableTextField: View {
    @Binding var text: String
    var placeholder: String = ""
    var font: Font = .body
    var uiFontSize: CGFloat = 17
    var uiFontWeight: PlatformFontWeight = .regular
    var strikethrough: Bool = false
    var multiline: Bool = false

    var onEnter: () -> Void = {}
    var onBackspaceEmpty: () -> Void = {}
    var onSlash: () -> Void = {}
    /// Direkter Callback statt NotificationCenter: `(BlockType, level)`.
    /// Wird aufgerufen wenn eine Markdown-Kurzbefehl-Sequenz erkannt wird
    /// (z.B. "# " → (.heading, 1)).
    var onMarkdownShortcut: ((BlockType, Int) -> Void)?

    var body: some View {
        Group {
            if multiline {
                TextEditor(text: $text)
                    .font(font)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .onChange(of: text) { old, new in handleChange(old: old, new: new) }
            } else {
                BlockTextField(
                    text: $text,
                    placeholder: placeholder,
                    font: font,
                    uiFontSize: uiFontSize,
                    uiFontWeight: uiFontWeight,
                    strikethrough: strikethrough,
                    onSubmit: onEnter,
                    onBackspaceEmpty: onBackspaceEmpty,
                    onTextChange: { old, new in handleChange(old: old, new: new) }
                )
            }
        }
    }

    private func handleChange(old: String, new: String) {
        if new.hasSuffix("/") && !old.hasSuffix("/") {
            onSlash()
        }
        // Markdown-Shortcuts: auch wenn der Block nicht leer war
        // (Notion-Verhalten: "# " am Anfang einer Zeile konvertiert den Block)
        let trimmed = new
        switch trimmed {
        case "# ":     text = ""; onMarkdownShortcut?(.heading, 1)
        case "## ":    text = ""; onMarkdownShortcut?(.heading, 2)
        case "### ":   text = ""; onMarkdownShortcut?(.heading, 3)
        case "- ", "* ":    text = ""; onMarkdownShortcut?(.bullet, 1)
        case "[] ", "[ ] ": text = ""; onMarkdownShortcut?(.todo, 1)
        case "1. ":    text = ""; onMarkdownShortcut?(.numbered, 1)
        case "> ":     text = ""; onMarkdownShortcut?(.quote, 1)
        case "\"\" ", ">> ": text = ""; onMarkdownShortcut?(.quote, 1)
        case "``` ":   text = ""; onMarkdownShortcut?(.code, 1)
        case "--- ", "*** ": text = ""; onMarkdownShortcut?(.divider, 1)
        case "! ", "!! ":   text = ""; onMarkdownShortcut?(.callout, 1)
        case "> > ":   text = ""; onMarkdownShortcut?(.toggle, 1)
        default: break
        }
    }
}
