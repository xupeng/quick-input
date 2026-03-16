import Testing
@testable import Quick_Input

@Suite("MarkdownHighlighter Tests")
struct MarkdownHighlighterTests {
    @Test("extracts H1 title from first line")
    func extractH1Title() {
        let md = "# Meeting Notes\n\nSome content"
        #expect(MarkdownHighlighter.extractTitle(from: md) == "Meeting Notes")
    }

    @Test("falls back to timestamp when no H1")
    func fallbackToTimestamp() {
        let md = "Just some text without a heading"
        let title = MarkdownHighlighter.extractTitle(from: md)
        let regex = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/
        #expect(title.contains(regex))
    }

    @Test("handles empty content")
    func emptyContent() {
        let title = MarkdownHighlighter.extractTitle(from: "")
        let regex = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/
        #expect(title.contains(regex))
    }

    @Test("H1 must be on first line")
    func h1NotOnFirstLine() {
        let md = "Some text\n# Not a title"
        let title = MarkdownHighlighter.extractTitle(from: md)
        let regex = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/
        #expect(title.contains(regex))
    }
}
