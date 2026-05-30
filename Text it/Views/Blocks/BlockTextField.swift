//
//  BlockTextField.swift
//  Text it
//
//  Plattform-spezifisches wachsendes Textfeld:
//  – iOS/visionOS: UITextView (kein Scribble, wächst vertikal, Zeilenumbruch automatisch)
//    Return         → neuen Block erstellen (onSubmit)
//    Shift+Return   → Zeilenumbruch innerhalb des Blocks
//    Backspace leer → Block löschen (onBackspaceEmpty)
//  – macOS: SwiftUI TextField mit axis: .vertical (wächst ebenfalls)
//

import SwiftUI

#if os(iOS) || os(visionOS)
import UIKit

// MARK: - UITextView-Subklasse (kein Scribble, Backspace-Event)

final class GrowingNoScribbleTextView: UITextView, UIScribbleInteractionDelegate {

    var onBackspaceEmpty: (() -> Void)?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isScrollEnabled = false
        backgroundColor = .clear
        textContainerInset = UIEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
        textContainer.lineFragmentPadding = 0
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)

        // Scribble blockieren
        let scribble = UIScribbleInteraction(delegate: self)
        addInteraction(scribble)
    }

    // Backspace auf leerem Feld erkennen
    override func deleteBackward() {
        if text.isEmpty {
            onBackspaceEmpty?()
        } else {
            super.deleteBackward()
        }
    }

    // Shift+Return → Zeilenumbruch (überschreibt Return-Handling im Delegate)
    override var keyCommands: [UIKeyCommand]? {
        let shiftReturn = UIKeyCommand(
            action: #selector(handleShiftReturn),
            input: "\r",
            modifierFlags: .shift,
            discoverabilityTitle: "Neue Zeile"
        )
        shiftReturn.wantsPriorityOverSystemBehavior = true
        return [shiftReturn]
    }

    @objc private func handleShiftReturn() {
        insertText("\n")
    }

    // UIScribbleInteractionDelegate
    func scribbleInteraction(_ interaction: UIScribbleInteraction,
                             shouldBeginAt location: CGPoint) -> Bool { false }
}

// MARK: - UIViewRepresentable Wrapper

struct GrowingTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var font: UIFont = .systemFont(ofSize: 17, weight: .regular)
    var strikethrough: Bool = false
    var onSubmit: () -> Void = {}
    var onBackspaceEmpty: () -> Void = {}
    var onTextChange: (String, String) -> Void = { _, _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // Erzwingt Textumbruch: die TextView passt sich der angebotenen Breite an
    // und wächst vertikal. Ohne diese Methode würde SwiftUI auf iPad manchmal
    // eine unendliche Breite anbieten und Text würde nicht umbrechen.
    func sizeThatFits(_ proposal: ProposedViewSize,
                      uiView: GrowingNoScribbleTextView,
                      context: Context) -> CGSize? {
        guard let w = proposal.width, w.isFinite, w > 0 else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude))
        return CGSize(width: w, height: max(fitted.height, uiView.font?.lineHeight ?? 20))
    }

    func makeUIView(context: Context) -> GrowingNoScribbleTextView {
        let tv = GrowingNoScribbleTextView()
        tv.delegate = context.coordinator
        tv.font = font
        tv.onBackspaceEmpty = { context.coordinator.parent.onBackspaceEmpty() }
        updateText(tv)
        return tv
    }

    func updateUIView(_ tv: GrowingNoScribbleTextView, context: Context) {
        context.coordinator.parent = self
        tv.font = font
        tv.onBackspaceEmpty = { context.coordinator.parent.onBackspaceEmpty() }
        if tv.text != text { updateText(tv) }
        // Platzhalter
        tv.textColor = text.isEmpty ? .placeholderText : .label
        if text.isEmpty && !tv.isFirstResponder { tv.text = placeholder }
    }

    private func updateText(_ tv: UITextView) {
        if strikethrough {
            let attr = NSMutableAttributedString(string: text)
            let range = NSRange(location: 0, length: text.utf16.count)
            if let f = tv.font { attr.addAttribute(.font, value: f, range: range) }
            attr.addAttribute(.strikethroughStyle,
                              value: NSUnderlineStyle.single.rawValue,
                              range: range)
            attr.addAttribute(.foregroundColor, value: UIColor.label, range: range)
            tv.attributedText = attr
        } else {
            tv.attributedText = nil
            tv.text = text.isEmpty ? placeholder : text
            tv.textColor = text.isEmpty ? .placeholderText : .label
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextField

        init(_ p: GrowingTextField) { self.parent = p }

        // Zeigt/versteckt Platzhalter
        func textViewDidBeginEditing(_ tv: UITextView) {
            if tv.text == parent.placeholder && tv.textColor == .placeholderText {
                tv.text = ""
                tv.textColor = .label
            }
        }

        func textViewDidEndEditing(_ tv: UITextView) {
            if tv.text.isEmpty {
                tv.text = parent.placeholder
                tv.textColor = .placeholderText
            }
        }

        func textViewDidChange(_ tv: UITextView) {
            let new = tv.text ?? ""
            let old = parent.text
            if old != new {
                parent.text = new
                parent.onTextChange(old, new)
            }
        }

        // Return → neuer Block; Shift+Return wird durch keyCommand abgefangen
        func textView(_ tv: UITextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {
            if text == "\n" {
                parent.onSubmit()
                return false
            }
            return true
        }
    }
}
#endif

// MARK: - BlockTextField (plattformübergreifend)

struct BlockTextField: View {
    @Binding var text: String
    var placeholder: String = ""
    var font: Font = .body
    var uiFontSize: CGFloat = 17
    var uiFontWeight: PlatformFontWeight = .regular
    var strikethrough: Bool = false
    var onSubmit: () -> Void = {}
    var onBackspaceEmpty: () -> Void = {}
    var onTextChange: (String, String) -> Void = { _, _ in }

    var body: some View {
        #if os(iOS) || os(visionOS)
        GrowingTextField(
            text: $text,
            placeholder: placeholder,
            font: UIFont.systemFont(ofSize: uiFontSize, weight: uiFontWeight),
            strikethrough: strikethrough,
            onSubmit: onSubmit,
            onBackspaceEmpty: onBackspaceEmpty,
            onTextChange: onTextChange
        )
        #else
        // macOS: TextField mit vertikaler Ausdehnung (wächst mit Inhalt)
        TextField(placeholder, text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .font(font)
            .strikethrough(strikethrough)
            .lineLimit(1...50)
            .onSubmit(onSubmit)
            .onChange(of: text) { old, new in onTextChange(old, new) }
        #endif
    }
}

// MARK: - PlatformFontWeight

#if os(iOS) || os(visionOS)
typealias PlatformFontWeight = UIFont.Weight
#else
enum PlatformFontWeight {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
}
#endif
