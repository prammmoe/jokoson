import Foundation
import SwiftUI

#if os(macOS)
import AppKit
typealias JSONSyntaxPlatformColor = NSColor
#else
import UIKit
typealias JSONSyntaxPlatformColor = UIColor
#endif

enum JSONSyntaxTheme {
    static var key: Color { .blue }
    static var string: Color { .green }
    static var number: Color { .orange }
    static var boolean: Color { .purple }
    static var null: Color { .secondary }
    static var punctuation: Color { .secondary }

    static func valueColor(for value: JSONValue) -> Color {
        switch value {
        case .object, .array: return .secondary
        case .string: return string
        case .number: return number
        case .bool: return boolean
        case .null: return null
        }
    }
}

enum JSONSyntaxHighlighter {
    static func attributedString(for text: String) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: platformColor(for: .text)
            ]
        )
        let source = text as NSString
        var index = 0

        while index < source.length {
            let character = source.character(at: index)

            if character == 0x22 { // quotation mark
                let end = endOfString(in: source, startingAt: index)
                var afterString = end
                while afterString < source.length, isWhitespace(source.character(at: afterString)) {
                    afterString += 1
                }
                let token = afterString < source.length && source.character(at: afterString) == 0x3A ? Token.key : Token.string
                add(token, to: result, range: NSRange(location: index, length: max(0, end - index)))
                index = max(index + 1, end)
                continue
            }

            if character == 0x2D || isDigit(character) {
                let end = endOfNumber(in: source, startingAt: index)
                add(.number, to: result, range: NSRange(location: index, length: end - index))
                index = end
                continue
            }

            if isLetter(character) {
                let end = endOfWord(in: source, startingAt: index)
                let word = source.substring(with: NSRange(location: index, length: end - index))
                if word == "true" || word == "false" {
                    add(.boolean, to: result, range: NSRange(location: index, length: end - index))
                } else if word == "null" {
                    add(.null, to: result, range: NSRange(location: index, length: end - index))
                }
                index = end
                continue
            }

            if isPunctuation(character) {
                add(.punctuation, to: result, range: NSRange(location: index, length: 1))
            }
            index += 1
        }

        return result
    }

    #if os(macOS)
    static var font: NSFont {
        .monospacedSystemFont(ofSize: 13, weight: .regular)
    }
    #else
    static var font: UIFont {
        .monospacedSystemFont(ofSize: 16, weight: .regular)
    }
    #endif

    private enum Token {
        case text, key, string, number, boolean, null, punctuation
    }

    private static func add(_ token: Token, to result: NSMutableAttributedString, range: NSRange) {
        guard range.length > 0 else { return }
        result.addAttribute(.foregroundColor, value: platformColor(for: token), range: range)
    }

    private static func platformColor(for token: Token) -> JSONSyntaxPlatformColor {
        #if os(macOS)
        switch token {
        case .text: return .labelColor
        case .key: return .systemBlue
        case .string: return .systemGreen
        case .number: return .systemOrange
        case .boolean: return .systemPurple
        case .null: return .secondaryLabelColor
        case .punctuation: return .tertiaryLabelColor
        }
        #else
        switch token {
        case .text: return .label
        case .key: return .systemBlue
        case .string: return .systemGreen
        case .number: return .systemOrange
        case .boolean: return .systemPurple
        case .null: return .secondaryLabel
        case .punctuation: return .tertiaryLabel
        }
        #endif
    }

    private static func endOfString(in source: NSString, startingAt start: Int) -> Int {
        var index = start + 1
        var escaped = false
        while index < source.length {
            let character = source.character(at: index)
            if escaped {
                escaped = false
            } else if character == 0x5C {
                escaped = true
            } else if character == 0x22 {
                return index + 1
            }
            index += 1
        }
        return source.length
    }

    private static func endOfNumber(in source: NSString, startingAt start: Int) -> Int {
        var index = start
        while index < source.length {
            let character = source.character(at: index)
            guard isDigit(character) || character == 0x2D || character == 0x2B || character == 0x2E || character == 0x65 || character == 0x45 else {
                break
            }
            index += 1
        }
        return max(start + 1, index)
    }

    private static func endOfWord(in source: NSString, startingAt start: Int) -> Int {
        var index = start
        while index < source.length, isLetter(source.character(at: index)) {
            index += 1
        }
        return index
    }

    private static func isWhitespace(_ character: unichar) -> Bool {
        character == 0x20 || character == 0x09 || character == 0x0A || character == 0x0D
    }

    private static func isDigit(_ character: unichar) -> Bool {
        (0x30...0x39).contains(character)
    }

    private static func isLetter(_ character: unichar) -> Bool {
        (0x41...0x5A).contains(character) || (0x61...0x7A).contains(character)
    }

    private static func isPunctuation(_ character: unichar) -> Bool {
        [0x7B, 0x7D, 0x5B, 0x5D, 0x2C, 0x3A].contains(character)
    }
}

struct SyntaxHighlightedTextEditor: View {
    @Binding var text: String
    let accessibilityIdentifier: String

    var body: some View {
        #if os(macOS)
        MacSyntaxHighlightedTextEditor(text: $text, accessibilityIdentifier: accessibilityIdentifier)
        #else
        IOSSyntaxHighlightedTextEditor(text: $text, accessibilityIdentifier: accessibilityIdentifier)
        #endif
    }
}

#if os(macOS)
private struct MacSyntaxHighlightedTextEditor: NSViewRepresentable {
    @Binding var text: String
    let accessibilityIdentifier: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = NSTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = false
        textView.font = JSONSyntaxHighlighter.font
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 8
        textView.textContainerInset = NSSize(width: 0, height: 10)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.setAccessibilityIdentifier(accessibilityIdentifier)

        scrollView.documentView = textView
        context.coordinator.refresh(textView, text: text)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.update(textView, text: text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacSyntaxHighlightedTextEditor
        private var isApplying = false

        init(_ parent: MacSyntaxHighlightedTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplying, let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func update(_ textView: NSTextView, text: String) {
            if textView.string != text {
                let selection = textView.selectedRange()
                isApplying = true
                textView.string = text
                refresh(textView, text: text)
                isApplying = false
                textView.setSelectedRange(clamped(selection, to: text.utf16.count))
            } else {
                refresh(textView, text: text)
            }
        }

        func refresh(_ textView: NSTextView, text: String) {
            let selection = textView.selectedRange()
            isApplying = true
            textView.textStorage?.setAttributedString(JSONSyntaxHighlighter.attributedString(for: text))
            textView.setSelectedRange(clamped(selection, to: text.utf16.count))
            isApplying = false
        }

        private func clamped(_ range: NSRange, to length: Int) -> NSRange {
            NSRange(location: min(range.location, length), length: min(range.length, max(0, length - min(range.location, length))))
        }
    }
}
#else
private struct IOSSyntaxHighlightedTextEditor: UIViewRepresentable {
    @Binding var text: String
    let accessibilityIdentifier: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = JSONSyntaxHighlighter.font
        textView.textColor = .label
        textView.tintColor = .label
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.accessibilityIdentifier = accessibilityIdentifier
        context.coordinator.refresh(textView, text: text)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.update(textView, text: text)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: IOSSyntaxHighlightedTextEditor
        private var isApplying = false

        init(_ parent: IOSSyntaxHighlightedTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplying else { return }
            parent.text = textView.text
        }

        func update(_ textView: UITextView, text: String) {
            if textView.text != text {
                let selection = textView.selectedRange
                isApplying = true
                textView.text = text
                refresh(textView, text: text)
                isApplying = false
                textView.selectedRange = clamped(selection, to: text.utf16.count)
            } else {
                refresh(textView, text: text)
            }
        }

        func refresh(_ textView: UITextView, text: String) {
            let selection = textView.selectedRange
            isApplying = true
            textView.attributedText = JSONSyntaxHighlighter.attributedString(for: text)
            textView.selectedRange = clamped(selection, to: text.utf16.count)
            isApplying = false
        }

        private func clamped(_ range: NSRange, to length: Int) -> NSRange {
            NSRange(location: min(range.location, length), length: min(range.length, max(0, length - min(range.location, length))))
        }
    }
}
#endif
