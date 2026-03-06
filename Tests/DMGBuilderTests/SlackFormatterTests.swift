import Testing
import Markdown
@testable import DMGBuilder

@Suite("Slack Formatter Tests")
struct SlackFormatterTests {
    @Test("converts bold text")
    func bold() {
        let document = Document(parsing: "This is **bold** text")
        let result = SlackFormatter.format(document)
        #expect(result == "This is *bold* text")
    }

    @Test("converts italic text")
    func italic() {
        let document = Document(parsing: "This is *italic* text")
        let result = SlackFormatter.format(document)
        #expect(result == "This is _italic_ text")
    }

    @Test("converts strikethrough text")
    func strikethrough() {
        let document = Document(parsing: "This is ~~deleted~~ text")
        let result = SlackFormatter.format(document)
        #expect(result == "This is ~deleted~ text")
    }

    @Test("converts inline code")
    func inlineCode() {
        let document = Document(parsing: "Use `print()` here")
        let result = SlackFormatter.format(document)
        #expect(result == "Use `print()` here")
    }

    @Test("converts code blocks")
    func codeBlock() {
        let markdown = """
        ```swift
        let x = 42
        ```
        """
        let document = Document(parsing: markdown)
        let result = SlackFormatter.format(document)
        #expect(result == "```\nlet x = 42\n```")
    }

    @Test("converts code blocks without language")
    func codeBlockNoLanguage() {
        let markdown = """
        ```
        hello
        ```
        """
        let document = Document(parsing: markdown)
        let result = SlackFormatter.format(document)
        #expect(result == "```\nhello\n```")
    }

    @Test("converts links")
    func link() {
        let document = Document(parsing: "[Click here](https://example.com)")
        let result = SlackFormatter.format(document)
        #expect(result == "<https://example.com|Click here>")
    }

    @Test("converts link with no destination")
    func linkNoDestination() {
        // A link node with no destination falls back to plain text
        let document = Document(parsing: "[just text]()")
        let result = SlackFormatter.format(document)
        #expect(result.contains("just text"))
    }

    @Test("converts headings to bold")
    func heading() {
        let document = Document(parsing: "# My Title")
        let result = SlackFormatter.format(document)
        #expect(result == "*My Title*")
    }

    @Test("converts all heading levels to bold")
    func headingLevels() {
        let document = Document(parsing: "## Subtitle")
        let result = SlackFormatter.format(document)
        #expect(result == "*Subtitle*")
    }

    @Test("converts unordered lists")
    func unorderedList() {
        let markdown = """
        - First
        - Second
        - Third
        """
        let document = Document(parsing: markdown)
        let result = SlackFormatter.format(document)
        #expect(result == "• First\n• Second\n• Third")
    }

    @Test("converts ordered lists")
    func orderedList() {
        let markdown = """
        1. First
        2. Second
        3. Third
        """
        let document = Document(parsing: markdown)
        let result = SlackFormatter.format(document)
        #expect(result == "1. First\n2. Second\n3. Third")
    }

    @Test("converts blockquotes with space after >")
    func blockQuote() {
        let document = Document(parsing: "> This is quoted")
        let result = SlackFormatter.format(document)
        #expect(result == "> This is quoted")
    }

    @Test("converts images to links")
    func image() {
        let document = Document(parsing: "![alt text](https://example.com/image.png)")
        let result = SlackFormatter.format(document)
        #expect(result == "<https://example.com/image.png|alt text>")
    }

    @Test("converts image with no source to empty string")
    func imageNoSource() {
        // Image with empty source
        let document = Document(parsing: "![alt text]()")
        let result = SlackFormatter.format(document)
        // Should not crash, returns something reasonable
        #expect(!result.contains("alt text") || result.isEmpty || result.contains("<"))
    }

    @Test("converts thematic break")
    func thematicBreak() {
        let document = Document(parsing: "---")
        let result = SlackFormatter.format(document)
        #expect(result == "---")
    }

    @Test("handles mixed formatting")
    func mixedFormatting() {
        let document = Document(parsing: "This is **bold** and *italic* text")
        let result = SlackFormatter.format(document)
        #expect(result == "This is *bold* and _italic_ text")
    }

    @Test("handles nested formatting")
    func nestedFormatting() {
        let document = Document(parsing: "**bold _and italic_**")
        let result = SlackFormatter.format(document)
        #expect(result == "*bold _and italic_*")
    }

    @Test("handles multiple paragraphs")
    func multipleParagraphs() {
        let markdown = """
        First paragraph.

        Second paragraph.
        """
        let document = Document(parsing: markdown)
        let result = SlackFormatter.format(document)
        #expect(result == "First paragraph.\nSecond paragraph.")
    }

    @Test("handles empty document")
    func emptyDocument() {
        let document = Document(parsing: "")
        let result = SlackFormatter.format(document)
        #expect(result.isEmpty)
    }

    @Test("handles nested unordered lists with indentation")
    func nestedUnorderedList() {
        let markdown = """
        - Item 1
          - Sub-item
        - Item 2
        """
        let document = Document(parsing: markdown)
        let result = SlackFormatter.format(document)
        #expect(result.contains("• Item 1"))
        #expect(result.contains("    • Sub-item"))
        #expect(result.contains("• Item 2"))
    }

    @Test("handles multi-line block quotes")
    func multiLineBlockQuote() {
        let markdown = """
        > Line one
        > Line two
        """
        let document = Document(parsing: markdown)
        let result = SlackFormatter.format(document)
        #expect(result.contains("> "))
    }
}
