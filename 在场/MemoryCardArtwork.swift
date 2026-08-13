import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum MemoryCardArtwork {
    static let folderName = "artifacts/phonograph-cards"

    static func image(for assetName: String) -> Image? {
        #if os(macOS)
        if let nsImage = NSImage(contentsOfFile: path(for: assetName)) {
            return Image(nsImage: nsImage)
        }
        #else
        if let uiImage = UIImage(contentsOfFile: path(for: assetName)) {
            return Image(uiImage: uiImage)
        }
        #endif
        return nil
    }

    static func path(for assetName: String) -> String {
        "/Users/xujinglei/StudioProjects/ZaiChang/\(folderName)/\(assetName).png"
    }
}
