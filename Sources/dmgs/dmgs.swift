import ArgumentParser

@main
struct DMGs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dmgs",
        abstract: "Create a DMG installer for macOS applications",
        discussion: """
            Creates a professional DMG installer with a custom background image,
            proper icon positioning, and an Applications folder symlink.
            The app name is automatically extracted from the .app bundle.
            """,
        version: "1.0.0",
        subcommands: [
            Create.self,
            Identities.self,
        ],
        defaultSubcommand: Create.self
    )
}
