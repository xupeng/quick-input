import AppKit
import Foundation

enum MarkdownHighlighter {
    // MARK: - Title Extraction

    static func extractTitle(from markdown: String) -> String {
        let firstLine = markdown.prefix(while: { $0 != "\n" })
        if let match = firstLine.wholeMatch(of: /^# (.+)$/) {
            return String(match.1)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }

    // MARK: - Syntax Highlighting

    static func applyHighlighting(to text: String, in textStorage: NSTextStorage) {
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let baseFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let baseColor = NSColor.labelColor

        // Reset to base style
        textStorage.addAttributes([
            .font: baseFont,
            .foregroundColor: baseColor
        ], range: fullRange)

        let nsText = text as NSString

        // Headings: # ## ###
        applyPattern(#"^(#{1,3})\s+(.+)$"#, to: nsText, in: textStorage) { range in
            let level = nsText.substring(with: range).prefix(while: { $0 == "#" }).count
            let size: CGFloat = [24, 20, 17][min(level - 1, 2)]
            return [.font: NSFont.monospacedSystemFont(ofSize: size, weight: .bold)]
        }

        // Bold: **text**
        applyPattern(#"\*\*(.+?)\*\*"#, to: nsText, in: textStorage) { _ in
            [.font: NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)]
        }

        // Italic: *text*
        applyPattern(#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, to: nsText, in: textStorage) { _ in
            [.font: NSFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits(.italic), size: 14) ?? baseFont]
        }

        // Inline code: `code`
        applyPattern(#"`([^`]+)`"#, to: nsText, in: textStorage) { _ in
            [.backgroundColor: NSColor.quaternaryLabelColor,
             .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)]
        }

        // Links: [text](url)
        applyPattern(#"\[([^\]]+)\]\([^\)]+\)"#, to: nsText, in: textStorage) { _ in
            [.foregroundColor: NSColor.linkColor]
        }

        // Block quotes: > text
        applyPattern(#"^>\s+(.+)$"#, to: nsText, in: textStorage) { _ in
            [.foregroundColor: NSColor.secondaryLabelColor]
        }

        // List markers: - or * or 1.
        applyPattern(#"^(\s*[-*]|\s*\d+\.)\s"#, to: nsText, in: textStorage) { _ in
            [.foregroundColor: NSColor.tertiaryLabelColor]
        }
    }

    private static func applyPattern(
        _ pattern: String,
        to text: NSString,
        in textStorage: NSTextStorage,
        attributes: (NSRange) -> [NSAttributedString.Key: Any]
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return }
        let fullRange = NSRange(location: 0, length: text.length)
        for match in regex.matches(in: text as String, range: fullRange) {
            textStorage.addAttributes(attributes(match.range), range: match.range)
        }
    }
}
