import Markdown

public struct SlackFormatter: MarkupVisitor {
    public typealias Result = String

    private var listDepth = 0

    public mutating func defaultVisit(_ markup: any Markup) -> String {
        markup.children.map { visit($0) }.joined()
    }

    public mutating func visitDocument(_ document: Document) -> String {
        document.children.map { visit($0) }.joined(separator: "\\n\\n")
    }

    public mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        paragraph.children.map { visit($0) }.joined()
    }

    public mutating func visitText(_ text: Text) -> String {
        text.string
    }

    public mutating func visitStrong(_ strong: Strong) -> String {
        let content = strong.children.map { visit($0) }.joined()
        return "*\(content)*"
    }

    public mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        let content = emphasis.children.map { visit($0) }.joined()
        return "_\(content)_"
    }

    public mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        let content = strikethrough.children.map { visit($0) }.joined()
        return "~\(content)~"
    }

    public mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "`\(inlineCode.code)`"
    }

    public mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        "```\(codeBlock.code)```"
    }

    public mutating func visitLink(_ link: Link) -> String {
        let text = link.children.map { visit($0) }.joined()
        guard let destination = link.destination else { return text }
        return "<\(destination)|\(text)>"
    }

    public mutating func visitImage(_ image: Image) -> String {
        guard let source = image.source else { return "" }
        let alt = image.children.map { visit($0) }.joined()
        return "<\(source)|\(alt)>"
    }

    public mutating func visitHeading(_ heading: Heading) -> String {
        let content = heading.children.map { visit($0) }.joined()
        return "*\(content)*\\n"
    }

    public mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        let content = blockQuote.children.map { visit($0) }.joined(separator: "\\n")
        return
            content
            .split(separator: "\\n", omittingEmptySubsequences: false)
            .map { "> \($0)" }
            .joined(separator: "\\n")
    }

    public mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        let indent = String(repeating: "    ", count: listDepth)
        let startIndex = Int(orderedList.startIndex)
        listDepth += 1
        var lines: [String] = []
        for (index, item) in orderedList.listItems.enumerated() {
            let content = item.children.map { visit($0) }.joined(separator: "\\n")
            lines.append("\(indent)\(startIndex + index). \(content)")
        }
        listDepth -= 1
        return lines.joined(separator: "\\n")
    }

    public mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        let indent = String(repeating: "    ", count: listDepth)
        listDepth += 1
        var lines: [String] = []
        for item in unorderedList.listItems {
            let content = item.children.map { visit($0) }.joined(separator: "\\n")
            lines.append("\(indent)• \(content)")
        }
        listDepth -= 1
        return lines.joined(separator: "\\n")
    }

    public mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "---"
    }

    public mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "\\n"
    }

    public mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        "\\n"
    }

    public static func format(_ document: Document) -> String {
        var formatter = SlackFormatter()
        return formatter.visit(document)
    }
}
