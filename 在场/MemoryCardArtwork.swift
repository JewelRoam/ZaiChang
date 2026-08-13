import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum MemoryCardArtwork {
    static let folderName = "MemoryCardArt"

    static func image(for assetName: String) -> Image? {
        guard let url = url(for: assetName) else { return nil }
        #if os(macOS)
        guard let nsImage = NSImage(contentsOf: url) else { return nil }
        return Image(nsImage: nsImage)
        #else
        guard let uiImage = UIImage(contentsOfFile: url.path) else { return nil }
        return Image(uiImage: uiImage)
        #endif
    }

    static func url(for assetName: String) -> URL? {
        let bundle = Bundle.main
        if let direct = bundle.url(forResource: assetName, withExtension: "png", subdirectory: folderName) {
            return direct
        }
        if let flattened = bundle.url(forResource: assetName, withExtension: "png") {
            return flattened
        }
        guard let sandbox = sandboxURL(for: assetName),
              FileManager.default.fileExists(atPath: sandbox.path)
        else { return nil }
        return sandbox
    }

    static func hasSandboxCopy(for assetName: String) -> Bool {
        guard let url = sandboxURL(for: assetName) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    static func sandboxURL(for assetName: String) -> URL? {
        AppStoragePaths.applicationSupportRoot()
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent("\(assetName).png")
    }
}
