//
//  HighlightedTextEditor.swift
//  CapsizedVault
//
//  A multiline text editor that underlines unrecognized words in red — used by the Monero
//  and Zcash seed-restore screens to flag words outside the expected wordlist.
//

import SwiftUI

struct HighlightedTextEditor: UIViewRepresentable {
    @Binding var text: String
    let unrecognizedWords: Set<String>
    var onFocusChange: ((Bool) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self

        if textView.text != text {
            textView.text = text
        }
        applyHighlighting(to: textView)
    }

    private func applyHighlighting(to textView: UITextView) {
        let currentText = textView.text ?? ""
        let font = UIFont.preferredFont(forTextStyle: .body)

        let attributed = NSMutableAttributedString(string: currentText, attributes: [
            .font: font,
            .foregroundColor: UIColor.label
        ])

        if !unrecognizedWords.isEmpty && !currentText.isEmpty {
            let regex = try? NSRegularExpression(pattern: "\\S+")
            let fullRange = NSRange(location: 0, length: (currentText as NSString).length)
            let matches = regex?.matches(in: currentText, range: fullRange) ?? []
            for match in matches {
                let word = (currentText as NSString).substring(with: match.range).lowercased()
                if unrecognizedWords.contains(word) {
                    attributed.addAttributes([
                        .foregroundColor: UIColor.systemRed,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .underlineColor: UIColor.systemRed
                    ], range: match.range)
                }
            }
        }

        let selectedRange = textView.selectedRange
        textView.attributedText = attributed
        textView.selectedRange = selectedRange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: HighlightedTextEditor

        init(_ parent: HighlightedTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onFocusChange?(true)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onFocusChange?(false)
        }
    }
}
