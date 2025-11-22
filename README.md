# DMGs

A simple CLI tool to create professional DMG installers for macOS applications.

## Features

- Creates styled DMG files with custom background images
- Automatically extracts app name from bundle Info.plist
- Automatically sizes DMG window to match background image dimensions
- Positions app icon and Applications folder symlink automatically based on image size
- Sets custom DMG icon by compositing app icon onto drive icon
- Code signing support with identity validation
- Compresses final DMG for distribution

## Installation

Build from source:

```bash
swift build -c release
```

Install to `/usr/local/bin`:

```bash
# Copy the binary
cp .build/release/dmgs /usr/local/bin/

# Or create a symlink (recommended for development)
ln -s $(pwd)/.build/release/dmgs /usr/local/bin/dmgs
```

## Usage

### Create a DMG (default command)

```bash
dmgs <app-path> <background-path> [options]
# or explicitly
dmgs create <app-path> <background-path> [options]
```

### List available signing identities

```bash
dmgs identities
```

### Arguments

- `app-path` - Path to the .app bundle
- `background-path` - Path to the background image for the DMG

The app name is automatically extracted from the bundle's `CFBundleDisplayName` or `CFBundleName` in Info.plist.

### Options

- `-o, --output <directory>` - Output directory for the DMG (defaults to current directory)
- `--icon-size <size>` - Icon size in the DMG window (default: 100)
- `--sign <identity>` - Code signing identity to sign the DMG (e.g., "Developer ID Application")
- `-v, --verbose` - Show verbose output
- `-h, --help` - Show help information

### Examples

Basic usage:

```bash
dmgs "/path/to/MyApp.app" "/path/to/background.png"
```

With custom options and code signing:

```bash
dmgs "/path/to/MyApp.app" "/path/to/background.png" \
  --output ~/Desktop \
  --icon-size 120 \
  --sign "Developer ID Application: Your Name (TEAM123)" \
  --verbose
```

List available signing identities:

```bash
dmgs identities
```


### Testing

Run tests:

```bash
swift test
```

## How It Works

1. **Configuration**
   - Extracts app name from Info.plist (`CFBundleDisplayName` or `CFBundleName`)
   - Reads background image dimensions
   - Calculates optimal window bounds (image size + 22px for title bar)
   - Calculates icon positions (app at 1/4 width, Applications at 3/4 width)
   - Validates signing identity if provided

2. **DMG Creation**
   - Creates a temporary DMG with auto-calculated size
   - Mounts the DMG
   - Copies app bundle to DMG
   - Creates Applications folder symlink
   - Copies background image to `.background` folder

3. **Customization**
   - Uses AppleScript to customize Finder window
   - Sets window bounds to match background image perfectly
   - Positions icons automatically based on image dimensions
   - Applies background image and icon size settings

4. **Finalization**
   - Unmounts the DMG
   - Converts to compressed, read-only format
   - Sets custom DMG icon (app icon composited onto drive icon)
   - Signs DMG if signing identity provided
   - Verifies signature contains Authority flag
   - Cleans up temporary files

The DMG window is automatically sized to match your background image, and icons are positioned proportionally, ensuring a perfect fit with no manual positioning needed.

## Dependencies

- [swift-argument-parser](https://github.com/apple/swift-argument-parser) - Command line argument parsing
- [swift-subprocess](https://github.com/swiftlang/swift-subprocess) - Modern async subprocess execution

## Requirements

- macOS 13.0 or later
- Swift 6.2 or later
- Xcode command line tools

## License

MIT
