import ArgumentParser
import DMGBuilder
import Foundation
import Markdown

extension DMGs {
    struct MarkdownToHTML: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "markdown",
            abstract: "Convert a Markdown file to HTML or Slack mrkdwn"
        )

        @Argument(help: "Path to the .md file to convert.")
        var inputPath: String

        @Option(name: .shortAndLong, help: "Output file path. Prints to stdout if not specified.")
        var output: String?

        @Flag(name: .long, help: "Output Slack mrkdwn format instead of HTML.")
        var slack: Bool = false

        mutating func run() async throws {
            let inputURL = URL(filePath: inputPath)

            guard FileManager.default.fileExists(atPath: inputURL.path) else {
                throw ValidationError("File not found: \(inputPath)")
            }

            let source = try String(contentsOf: inputURL, encoding: .utf8)
            let document = Document(parsing: source)
            let result = slack
                ? SlackFormatter.format(document)
                : HTMLFormatter.format(document)

            if let output {
                let outputURL = URL(filePath: output)
                try result.write(to: outputURL, atomically: true, encoding: .utf8)
                FileHandle.standardError.write(Data("Written to \(output)\n".utf8))
            } else {
                print(result)
            }
        }
    }
}
