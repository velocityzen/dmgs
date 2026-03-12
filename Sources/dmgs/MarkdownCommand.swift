import ArgumentParser
import DMGBuilder
import FP
import Foundation
import Markdown

extension DMGs {
    struct MarkdownToHTML: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "markdown",
            abstract: "Convert a Markdown file to HTML or Slack mrkdwn"
        )

        @Argument(help: "Path to the .md file to convert. Reads from stdin if not specified.")
        var inputPath: String?

        @Option(name: .shortAndLong, help: "Output file path. Prints to stdout if not specified.")
        var output: String?

        @Flag(name: .long, help: "Output Slack mrkdwn format instead of HTML.")
        var slack: Bool = false

        mutating func run() async throws {
            try convertMarkdown().commandValue()
        }

        private func convertMarkdown() -> Result<Void, DMGsCommandError> {
            readSource()
                .map { Document(parsing: $0) }
                .map { document in
                    slack
                        ? SlackFormatter.format(document)
                        : HTMLFormatter.format(document)
                }
                .flatMap(writeOutput)
        }

        private func readSource() -> Result<String, DMGsCommandError> {
            if let inputPath {
                return readFile(at: inputPath)
            }

            return readStandardInput()
        }

        private func readFile(at path: String) -> Result<String, DMGsCommandError> {
            let inputURL = URL(filePath: path)

            guard FileManager.default.fileExists(atPath: inputURL.path) else {
                return .failure(.fileNotFound(path: path))
            }

            return Result<String, Error> {
                try String(contentsOf: inputURL, encoding: .utf8)
            }
            .mapError {
                .inputReadFailed(path: path, reason: $0.localizedDescription)
            }
        }

        private func readStandardInput() -> Result<String, DMGsCommandError> {
            Result<Data?, Error> {
                try FileHandle.standardInput.readToEnd()
            }
            .mapError {
                .standardInputReadFailed(reason: $0.localizedDescription)
            }
            .flatMap { data in
                Result<Data, DMGsCommandError>.fromOptional(
                    data,
                    error: .standardInputReadFailed(reason: "No input received")
                )
            }
            .flatMap { data in
                Result<String, DMGsCommandError>.fromOptional(
                    String(data: data, encoding: .utf8),
                    error: .standardInputReadFailed(reason: "Input was not valid UTF-8")
                )
            }
        }

        private func writeOutput(_ html: String) -> Result<Void, DMGsCommandError> {
            guard let output else {
                print(html)
                return .success(())
            }

            let outputURL = URL(filePath: output)

            return Result<Void, Error> {
                try html.write(to: outputURL, atomically: true, encoding: .utf8)
            }
            .mapError {
                .outputWriteFailed(path: output, reason: $0.localizedDescription)
            }
            .tap { _ in
                writeStandardError("Written to \(output)\n")
            }
        }

        private func writeStandardError(_ message: String) {
            FileHandle.standardError.write(Data(message.utf8))
        }
    }
}
