import Markdown

struct SlackFormatter: MarkupVisitor {
    typealias Result = String

    mutating func defaultVisit(_ markup: any Markup) -> String {
        markup.children.map { visit($0) }.joined()
    }

    mutating func visitDocument(_ document: Document) -> String {
        document.children.map { visit($0) }.joined(separator: "\n")
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        paragraph.children.map { visit($0) }.joined()
    }

    mutating func visitText(_ text: Text) -> String {
        text.string
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        let content = strong.children.map { visit($0) }.joined()
        return "*\(content)*"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        let content = emphasis.children.map { visit($0) }.joined()
        return "_\(content)_"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        let content = strikethrough.children.map { visit($0) }.joined()
        return "~\(content)~"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "`\(inlineCode.code)`"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        "```\n\(codeBlock.code)```"
    }

    mutating func visitLink(_ link: Link) -> String {
        let text = link.children.map { visit($0) }.joined()
        guard let destination = link.destination else { return text }
        return "<\(destination)|\(text)>"
    }

    mutating func visitImage(_ image: Image) -> String {
        guard let source = image.source else { return "" }
        let alt = image.children.map { visit($0) }.joined()
        return "<\(source)|\(alt)>"
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let content = heading.children.map { visit($0) }.joined()
        return "*\(content)*"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        let content = blockQuote.children.map { visit($0) }.joined(separator: "\n")
        return content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { ">\($0)" }
            .joined(separator: "\n")
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        var lines: [String] = []
        for (index, item) in orderedList.listItems.enumerated() {
            let content = item.children.map { visit($0) }.joined()
            lines.append("\(index + 1). \(content)")
        }
        return lines.joined(separator: "\n")
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        var lines: [String] = []
        for item in unorderedList.listItems {
            let content = item.children.map { visit($0) }.joined()
            lines.append("• \(content)")
        }
        return lines.joined(separator: "\n")
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "---"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "\n"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        "\n"
    }

    static func format(_ document: Document) -> String {
        var formatter = SlackFormatter()
        return formatter.visit(document)
    }
}
