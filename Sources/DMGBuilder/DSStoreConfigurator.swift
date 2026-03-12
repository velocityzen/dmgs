import DSStore
import Foundation

enum DSStoreConfigurator {
    static func configure(
        volumeURL: URL,
        appFileName: String,
        backgroundFileName: String,
        iconSize: Int,
        windowBounds: (left: Int, top: Int, right: Int, bottom: Int),
        appPosition: (x: Int, y: Int),
        applicationsPosition: (x: Int, y: Int)
    ) throws {
        let backgroundFileURL =
            volumeURL
            .appending(path: ".background", directoryHint: .isDirectory)
            .appending(path: backgroundFileName)
        let target = try DSStoreFolderTarget.resolve(folderURL: volumeURL)
            .mapError()
            .get()

        let updatedStore = try target.readStore()
            .flatMap { store in
                applyWindowSettings(
                    to: store,
                    recordName: target.recordName,
                    iconSize: iconSize,
                    windowBounds: windowBounds
                )
            }
            .flatMap { store in
                applyBackgroundImage(
                    to: store,
                    recordName: target.recordName,
                    backgroundFileURL: backgroundFileURL,
                    iconSize: iconSize
                )
            }
            .flatMap { store in
                applyIconLocation(
                    to: store,
                    itemName: appFileName,
                    position: appPosition
                )
            }
            .flatMap { store in
                applyIconLocation(
                    to: store,
                    itemName: "Applications",
                    position: applicationsPosition
                )
            }
            .mapError()
            .get()

        try target.writeStore(updatedStore)
            .mapError()
            .get()
    }

    private static func applyBackgroundImage(
        to store: DSStoreFile,
        recordName: String,
        backgroundFileURL: URL,
        iconSize _: Int
    ) -> Result<DSStoreFile, DSStoreError> {
        DSStoreBackground.picture(fileURL: backgroundFileURL)
            .flatMap { store.settingBackground($0, for: recordName) }
    }

    private static func applyWindowSettings(
        to store: DSStoreFile,
        recordName: String,
        iconSize: Int,
        windowBounds: (left: Int, top: Int, right: Int, bottom: Int)
    ) -> Result<DSStoreFile, DSStoreError> {
        let width = windowBounds.right - windowBounds.left
        let height = windowBounds.bottom - windowBounds.top

        guard let x = UInt16(exactly: windowBounds.left),
            let y = UInt16(exactly: windowBounds.top),
            let width = UInt16(exactly: width),
            let height = UInt16(exactly: height),
            let iconSize = UInt16(exactly: iconSize)
        else {
            return .failure(
                .unsupportedWriteValue("Window bounds or icon size exceed Finder limits"))
        }

        return
            store
            .settingWindowSettings(
                DSStoreWindowUpdate(
                    x: x,
                    y: y,
                    width: width,
                    height: height,
                    view: "icnv",
                    containerShowSidebar: false,
                    showSidebar: false,
                    showStatusBar: false,
                    showToolbar: false
                ),
                for: recordName
            )
            .flatMap { updatedStore in
                makeEntry(
                    filename: recordName,
                    structureID: "vstl",
                    value: .type("icnv")
                )
                .flatMap { viewStyleEntry in
                    makeEntry(
                        filename: recordName,
                        structureID: "ICVO",
                        value: .bool(true)
                    )
                    .flatMap { iconViewEnabledEntry in
                        makeEntry(
                            filename: recordName,
                            structureID: "icvt",
                            value: .short(13)
                        )
                        .flatMap { labelSizeEntry in
                            makeEntry(
                                filename: recordName,
                                structureID: "icvo",
                                value: .blob(iconViewOptionsData(iconSize: iconSize))
                            )
                            .map { iconViewOptionsEntry in
                                let withViewStyle = replacing(
                                    entry: viewStyleEntry, in: updatedStore)
                                let withIconViewEnabled = replacing(
                                    entry: iconViewEnabledEntry,
                                    in: withViewStyle
                                )
                                let withLabelSize = replacing(
                                    entry: labelSizeEntry,
                                    in: withIconViewEnabled
                                )
                                return replacing(entry: iconViewOptionsEntry, in: withLabelSize)
                            }
                        }
                    }
                }
            }
    }

    private static func applyIconLocation(
        to store: DSStoreFile,
        itemName: String,
        position: (x: Int, y: Int)
    ) -> Result<DSStoreFile, DSStoreError> {
        guard let x = UInt32(exactly: position.x), let y = UInt32(exactly: position.y) else {
            return .failure(.unsupportedWriteValue("Icon position exceeds Finder limits"))
        }

        return makeEntry(
            filename: itemName,
            structureID: "Iloc",
            value: .blob(iconLocationData(x: x, y: y))
        )
        .map { replacing(entry: $0, in: store) }
    }

    private static func iconViewOptionsData(iconSize: UInt16) -> Data {
        var data = Data()
        data.append(contentsOf: [0x69, 0x63, 0x76, 0x34])
        data.append(contentsOf: iconSize.bigEndianBytes)
        data.append(contentsOf: Array("none".utf8))
        data.append(contentsOf: Array("botm".utf8))
        data.append(contentsOf: [0x00, 0x00])
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x04])
        data.append(contentsOf: [0x00, 0x00])
        return data
    }

    private static func iconLocationData(x: UInt32, y: UInt32) -> Data {
        var data = Data()
        data.append(contentsOf: x.bigEndianBytes)
        data.append(contentsOf: y.bigEndianBytes)
        data.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00])
        return data
    }

    private static func makeEntry(
        filename: String,
        structureID: String,
        value: DSStoreValue
    ) -> Result<DSStoreEntry, DSStoreError> {
        DSStoreEntry.make(filename: filename, structureID: structureID, value: value)
    }

    private static func replacing(entry: DSStoreEntry, in store: DSStoreFile) -> DSStoreFile {
        let filtered = store.entries.filter {
            !($0.filename == entry.filename && $0.structureID == entry.structureID)
        }
        return DSStoreFile(entries: filtered + [entry])
    }
}

private extension Result where Failure == DSStoreError {
    func mapError() -> Result<Success, DMGBuilderError> {
        mapError { .dsStoreFailed(output: $0.localizedDescription) }
    }
}

private extension UInt16 {
    var bigEndianBytes: [UInt8] {
        [UInt8(self >> 8), UInt8(self & 0xFF)]
    }
}

private extension UInt32 {
    var bigEndianBytes: [UInt8] {
        [
            UInt8((self >> 24) & 0xFF),
            UInt8((self >> 16) & 0xFF),
            UInt8((self >> 8) & 0xFF),
            UInt8(self & 0xFF),
        ]
    }
}
