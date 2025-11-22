# DMGs

A simple CLI tool to create professional DMG installers for macOS applications.

## Features

- Creates styled DMG files with custom background images
- Automatically sizes DMG window to match background image dimensions
- Positions app icon and Applications folder symlink automatically
- Compresses final DMG for distribution
- Clean, testable architecture with separated concerns
- Built with Swift Argument Parser for robust CLI handling

## Installation

Build from source:

```bash
swift build -c release
cp .build/release/dmgs /usr/local/bin/
```

## Usage

```bash
dmgs <app-name> <app-path> <background-path> [options]
```

### Arguments

- `app-name` - Name for the DMG file (without .dmg extension)
- `app-path` - Path to the .app bundle
- `background-path` - Path to the background image for the DMG

### Options

- `-o, --output <directory>` - Output directory for the DMG (defaults to current directory)
- `-s, --size <size>` - DMG volume size (default: 200m)
- `--icon-size <size>` - Icon size in the DMG window (default: 100)
- `-v, --verbose` - Show verbose output
- `-h, --help` - Show help information

### Example

```bash
dmgs "MyApp" "/path/to/MyApp.app" "/path/to/background.png"
```

With custom options:

```bash
dmgs "MyApp" "/path/to/MyApp.app" "/path/to/background.png" \
  --output ~/Desktop \
  --size 300m \
  --icon-size 120 \
  --verbose
```

## Architecture

The project is structured with clean separation of concerns:

### Modules

- **dmgs** - CLI interface using Swift Argument Parser
- **DMGBuilder** - Core DMG creation logic (testable, reusable)

### DMGBuilder Components

- `DMGConfiguration` - Immutable configuration for DMG creation
- `DMGBuilder` - Main builder orchestrating the DMG creation process
- `ShellExecutor` - Protocol-based shell command execution (mockable for testing)
- `AppleScriptGenerator` - Generates AppleScript for Finder customization
- `DMGBuilderError` - Typed errors with clear descriptions

### Testing

Run tests:

```bash
swift test
```

The architecture makes it easy to:
- Unit test individual components
- Mock shell execution for testing
- Verify configuration logic
- Test AppleScript generation

## How It Works

1. Validates app file and background image exist
2. Reads background image dimensions to determine window size
3. Creates a temporary DMG with specified size
4. Mounts the DMG
5. Copies app bundle to DMG
6. Creates Applications folder symlink
7. Copies background image to `.background` folder
8. Uses AppleScript to customize Finder window (positions, background, icon size, window bounds)
9. Unmounts the DMG
10. Converts to compressed, read-only format
11. Cleans up temporary files

The DMG window is automatically sized to match your background image, ensuring a perfect fit with no cropping or empty space.

## Requirements

- macOS 13.0 or later
- Swift 6.2 or later
- Xcode command line tools

## License

MIT
