import Testing
import Markdown
@testable import dmgs

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

    @Test("converts links")
    func link() {
        let document = Document(parsing: "[Click here](https://example.com)")
        let result = SlackFormatter.format(document)
        #expect(result == "<https://example.com|Click here>")
    }

    @Test("converts headings to bold")
    func heading() {
        let document = Document(parsing: "# My Title")
        let result = SlackFormatter.format(document)
        #expect(result == "*My Title*")
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

    @Test("converts blockquotes")
    func blockQuote() {
        let document = Document(parsing: "> This is quoted")
        let result = SlackFormatter.format(document)
        #expect(result == ">This is quoted")
    }

    @Test("converts images to links")
    func image() {
        let document = Document(parsing: "![alt text](https://example.com/image.png)")
        let result = SlackFormatter.format(document)
        #expect(result == "<https://example.com/image.png|alt text>")
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
}
